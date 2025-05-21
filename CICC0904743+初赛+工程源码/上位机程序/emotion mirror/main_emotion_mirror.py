import sys
import socket
import numpy as np
import cv2
import threading  # Import the threading module
from PyQt5.QtWidgets import QApplication, QMainWindow, QLabel, QVBoxLayout, QWidget, QPushButton, QTextEdit, QHBoxLayout
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QImage, QPixmap, QFont
import pyttsx3
from ultralytics import YOLO
from openai import OpenAI

# ----------------- 语音线程类 -----------------
engine = pyttsx3.init()
engine.setProperty('rate', 170)
engine.setProperty('volume', 1.0)
for voice in engine.getProperty('voices'):
    if "zh" in voice.id or "chinese" in voice.name.lower():
        engine.setProperty('voice', voice.id)
        break

speech_lock = threading.Lock()

class SpeechWorker(QThread):
    def __init__(self, text):
        super().__init__()
        self.text = text

    def run(self):
        engine.say(self.text)
        engine.runAndWait()

# ----------------- 图像接收线程 -----------------
IMG_W, IMG_H = 1280, 720
BYTES_PER_LINE = 2 + IMG_W * 2
HOST, PORT = "192.168.0.3", 6102
SORT_LINES = True

class FrameListener(QThread):
    frame_ready = pyqtSignal(np.ndarray)

    def __init__(self):
        super().__init__()
        self._active = False
        self._socket = None

    def stop(self):
        self._active = False
        if self._socket:
            try:
                self._socket.close()
            except:
                pass
            self._socket = None

    def run(self):
        self._active = True
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 2**20)
        self._socket.bind((HOST, PORT))
        self._socket.settimeout(0.1)

        lines = {}

        while self._active:
            try:
                data, _ = self._socket.recvfrom(4096)
                if len(data) != BYTES_PER_LINE:
                    continue

                idx = int.from_bytes(data[:2], 'little')
                if 0 <= idx < IMG_H:
                    lines[idx] = data[2:]

                if len(lines) == IMG_H:
                    try:
                        full = b''.join(lines[i] for i in sorted(lines)) if SORT_LINES else b''.join(lines[i] for i in range(IMG_H))
                        pixels = np.frombuffer(full, dtype=np.uint16)
                        r = ((pixels >> 11) & 0x1F) << 3
                        g = ((pixels >> 5) & 0x3F) << 2
                        b = (pixels & 0x1F) << 3
                        img = np.stack((r, g, b), axis=-1).astype(np.uint8).reshape((IMG_H, IMG_W, 3))
                        self.frame_ready.emit(img.copy())
                    except:
                        pass
                    finally:
                        lines.clear()
            except:
                continue

# ----------------- Emotion Detection Worker -----------------
class DetectionWorker(QThread):
    processed = pyqtSignal(np.ndarray, np.ndarray)

    def __init__(self, model):
        super().__init__()
        self.model = model
        self._queue = []
        self._active = True

    def stop(self):
        self._active = False
        self.wait()

    def add(self, frame):
        if len(self._queue) < 5:  # Limiting the queue size
            self._queue.append(frame)

    def run(self):
        while self._active:
            if self._queue:
                frame = self._queue.pop(0)
                img_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                result = self.model(img_bgr)[0]
                visual = cv2.cvtColor(result.plot(), cv2.COLOR_BGR2RGB)
                self.processed.emit(frame, visual)
            else:
                self.msleep(5)

# ----------------- Deepseek API client -------------------
client = OpenAI(api_key="sk-91409a846ef6407d95b1dfa46fa24234", base_url="https://api.deepseek.com")

class SuggestionWorker(QThread):
    result_ready = pyqtSignal(str)

    def __init__(self, emotion):
        super().__init__()
        self.emotion = emotion

    def run(self):
        try:
            prompt = f"根据情绪 {self.emotion}，给出一个简短的建议或评价，要求口语化，分隔简短有趣，回复和真人聊天一样，不要加表情。"
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[{"role": "user", "content": prompt}]
            )
            suggestion = response.choices[0].message.content.strip()
        except Exception as e:
            suggestion = f"获取建议失败：{e}"
        self.result_ready.emit(suggestion)

# ----------------- GUI Setup -------------------
class VisualApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("情绪检测与反馈")
        self.resize(1400, 1000)
        self.setStyleSheet("background-color: #e8f0fe;")

        # Load emotion detection model (YOLOv8 for emotion detection)
        self._emotion_model = YOLO("Human_face_emotions.pt")  # Emotion detection model
        self._emotion_detector = DetectionWorker(self._emotion_model)
        self._emotion_detector.processed.connect(self.update_emotion_view)
        self._emotion_detector.start()

        # Setup image receiver (for real-time frame capture)
        self._receiver = FrameListener()
        self._receiver.frame_ready.connect(self.enqueue_image)
        self._receiver.start()

        self._init_ui()

    def _init_ui(self):
        # Label for emotion detection result
        self._emotion_label = QLabel("情绪检测显示区域")
        self._emotion_label.setAlignment(Qt.AlignCenter)
        self._emotion_label.setFixedSize(IMG_W, IMG_H)
        self._emotion_label.setStyleSheet("border: 2px solid #333; background-color: lightgray;")

        # Text area for Deepseek suggestion response
        self._info = QTextEdit()
        self._info.setReadOnly(True)
        self._info.setFixedHeight(200)
        self._info.setStyleSheet("background-color: #ffffff; font-size: 20px; padding: 16px;")

        # Button to trigger the Deepseek API
        self.btn_get_suggestion = QPushButton("🟢 获取建议")
        self.btn_get_suggestion.setFixedSize(200, 50)
        self.btn_get_suggestion.setStyleSheet("font-size: 18px; font-weight: bold; border-radius: 10px;")
        self.btn_get_suggestion.clicked.connect(self.get_suggestion)

        # 顶部 logo 和标题
        logo_left = QLabel()
        logo_left.setPixmap(QPixmap("logo.png").scaled(400, 400, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        logo_left.setAlignment(Qt.AlignLeft | Qt.AlignTop)

        logo_right = QLabel()
        logo_right.setPixmap(QPixmap("logo2.png").scaled(400, 400, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        logo_right.setAlignment(Qt.AlignRight | Qt.AlignTop)

        # 顶部区域：左上角 logo + 中间标题
        top_bar = QHBoxLayout()
        top_bar.addWidget(logo_left, alignment=Qt.AlignLeft)
        top_bar.addStretch()
        top_bar.addWidget(logo_right, alignment=Qt.AlignRight)

        title = QLabel("Magic Mirror")
        title.setFont(QFont("Arial", 32, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("color: #2a4d69; margin-top: 10px;")

        # Layout setup
        layout = QVBoxLayout()
        layout.addLayout(top_bar)
        layout.addWidget(title, alignment=Qt.AlignCenter)
        layout.addWidget(self._emotion_label, alignment=Qt.AlignCenter)
        layout.addWidget(self._info)
        layout.addWidget(self.btn_get_suggestion)

        wrapper = QWidget()
        wrapper.setLayout(layout)
        self.setCentralWidget(wrapper)

    def enqueue_image(self, image):
        self._emotion_detector.add(image)

    def update_emotion_view(self, raw, annotated):
        # 先显示标注图
        emotion_qimg = QImage(
            annotated.data, annotated.shape[1], annotated.shape[0],
            annotated.shape[1]*3, QImage.Format_RGB888
        )
        self._emotion_label.setPixmap(QPixmap.fromImage(emotion_qimg))

        # 再尝试提取情绪
        emo = self._extract_emotion(raw)
        if emo is not None:
            self._latest_emotion = emo


    def _extract_emotion(self, frame):
        bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        results = self._emotion_model(bgr)[0]
        # 如果没框，就直接返回 None（或其他默认值）
        if not hasattr(results, 'boxes') or len(results.boxes.cls) == 0:
            return None

        emotion_idx = int(results.boxes.cls[0])
        # results.names 可能是 dict 或 list
        if isinstance(results.names, dict):
            return results.names.get(emotion_idx, None)
        else:
            return results.names[emotion_idx]


    def get_suggestion(self):
        if hasattr(self, "_latest_emotion"):
            self._suggest_thread = SuggestionWorker(self._latest_emotion)
            self._suggest_thread.result_ready.connect(self.display_suggestion)
            self._suggest_thread.start()

    def display_suggestion(self, suggestion):
        self._info.setPlainText(f"建议：{suggestion}")
        self._speak(suggestion)

    def _speak(self, text):
        self._speech_thread = SpeechWorker(text)
        self._speech_thread.start()

# Main Application Execution
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = VisualApp()
    window.show()
    sys.exit(app.exec_())
