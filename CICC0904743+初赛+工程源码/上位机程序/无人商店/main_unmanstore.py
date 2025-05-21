import sys
import socket
import numpy as np
import cv2
from collections import Counter
from PyQt5.QtWidgets import QApplication, QMainWindow, QLabel, QVBoxLayout, QWidget, QPushButton, QHBoxLayout, QTextEdit
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QImage, QPixmap, QFont
from PyQt5.QtCore import QTimer
from ultralytics import YOLO
from catalog import catalog
import pyttsx3
import threading
from openai import OpenAI

# ----------------- 语音线程类 -----------------
# ----------------- 全局语音初始化 -----------------
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
        with speech_lock:
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
        if len(self._queue) < 2:
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

# ---------------- API client -------------------
client = OpenAI(api_key="sk-91409a846ef6407d95b1dfa46fa24234", base_url="https://api.deepseek.com")

class SuggestionWorker(QThread):
    result_ready = pyqtSignal(str)

    def __init__(self, summary_text):
        super().__init__()
        self.summary_text = summary_text

    def run(self):
        try:
            prompt = f"用户刚刚购买了以下商品：{self.summary_text}请你用一句话给用户一些建议或者评价，要求口语化，分隔简短有趣，回复和真人聊天一样，不要加表情。"
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            suggestion = response.choices[0].message.content.strip()
        except Exception as e:
            suggestion = f"建议获取失败：{e}"
        self.result_ready.emit(suggestion)

class VisualApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("智感交互式零售舱")
        self.resize(1400, 1000)
        self.setStyleSheet("background-color: #e8f0fe;")

        self._model = YOLO("yolov8s.pt")
        self._detector = DetectionWorker(self._model)
        self._detector.processed.connect(self.update_view)
        self._detector.start()

        self._receiver = FrameListener()
        self._receiver.frame_ready.connect(self.enqueue_image)
        self._receiver.start()

        self._latest = []
        self._opened = []
        self._closed = []

        self._init_ui()

    def _init_ui(self):
        self._label = QLabel("检测图像显示区域")
        self._label.setAlignment(Qt.AlignCenter)
        self._label.setFixedSize(IMG_W, IMG_H)
        self._label.setStyleSheet("border: 2px solid #333; background-color: white;")

        self._info = QTextEdit()
        self._info.setReadOnly(True)
        self._info.setFixedHeight(200)
        self._info.setStyleSheet("background-color: #ffffff; font-size: 24px; padding: 16px;")

        btn_open = QPushButton("🟢 开柜")
        btn_close = QPushButton("🔴 关柜")

        for b in (btn_open, btn_close):
            b.setFixedSize(150, 55)
            b.setStyleSheet("font-size: 20px; font-weight: bold; border-radius: 10px;")

        btn_open.clicked.connect(self.handle_open)
        btn_close.clicked.connect(self.handle_close)

        btn_box = QHBoxLayout()
        btn_box.addWidget(btn_open)
        btn_box.addWidget(btn_close)
        btn_box.setSpacing(40)

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

        title = QLabel("校园自动售货柜")
        title.setFont(QFont("Arial", 32, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("color: #2a4d69; margin-top: 10px;")

        # 总体布局
        layout = QVBoxLayout()
        layout.addLayout(top_bar)
        layout.addWidget(title, alignment=Qt.AlignCenter)
        layout.addWidget(self._label, alignment=Qt.AlignCenter)
        layout.addLayout(btn_box)
        layout.addWidget(self._info)

        wrapper = QWidget()
        wrapper.setLayout(layout)
        self.setCentralWidget(wrapper)

    def enqueue_image(self, image):
        self._detector.add(image)

    def update_view(self, raw, annotated):
        qimg = QImage(annotated.data, annotated.shape[1], annotated.shape[0], annotated.shape[1]*3, QImage.Format_RGB888)
        self._label.setPixmap(QPixmap.fromImage(qimg))
        self._latest = self._extract_labels(raw)

    def _extract_labels(self, frame):
        bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        results = self._model(bgr)[0]
        return [self._model.names[int(c)] for c in results.boxes.cls]

    def handle_open(self):
        self._info.setHtml('<span style="font-size:28px;">柜门已打开，请取走商品...</span>')
        self._speak("柜门已打开，请取走商品")
        self._opened = self._latest.copy()

    def handle_close(self):
        self._closed = self._latest.copy()
        self._summarize()
        # 🔁 延迟500ms调用建议，确保语音和检测处理完毕
        QTimer.singleShot(100, self._start_suggestion)

    def _summarize(self):
        purchased = Counter(self._opened) - Counter(self._closed)

        total = 0
        output = ["🛒 购物清单："]
        speak_text = "您购买了："

        for item, count in purchased.items():
            if item in catalog:
                label = catalog[item]["name"]
                price = catalog[item]["price"]
                output.append(f"{label} x{count} - ¥{price * count}")
                speak_text += f"{label} {count}件，"
                total += price * count
            else:
                output.append(f"{item} x{count} - 未知价格")
                speak_text += f"{item} {count}件，"

        if total == 0:
            output = ["🛒 您本次购买共计 0 元", "欢迎下次光临！"]
            self._info.setPlainText("\n".join(output))
            self._speak("欢迎下次光临")
        else:
            output.append(f"\n💰 需要支付: ¥{total}")
            speak_text += f"共计 {total} 元"
            self._info.setPlainText("\n".join(output))
            self._speak(speak_text)

    def closeEvent(self, event):
        if self._detector:
            self._detector.stop()
        if self._receiver:
            self._receiver.stop()
        event.accept()

    def _speak(self, text):
        self._speech_thread = SpeechWorker(text)
        self._speech_thread.start()

    def display_suggestion(self, suggestion):
        self._info.append(f"\n💡 智能建议：{suggestion}")
        self._speak(f"\n {suggestion}")

        # —— 新增：再延迟 200ms 触发补货提醒 —— #
        QTimer.singleShot(200, self._restock_reminder)
        # ———————————————————————— #

    def _start_suggestion(self):
        # 构建购买摘要
        purchased = Counter(self._opened) - Counter(self._closed)
        purchase_summary = ""
        for item, count in purchased.items():
            if item in catalog:
                label = catalog[item]["name"]
                purchase_summary += f"{label} {count}件，"
            else:
                purchase_summary += f"{item} {count}件，"

        if purchase_summary.strip():  # 有购买记录才发送
            self._suggest_thread = SuggestionWorker(purchase_summary)
            self._suggest_thread.result_ready.connect(self.display_suggestion)
            self._suggest_thread.start()
        else:
            # —— 新增：再延迟 200ms 触发补货提醒 —— #
            QTimer.singleShot(200, self._restock_reminder)
            # ———————————————————————— #

    def _restock_reminder(self):
        total_labels = len(self._closed)
        if total_labels == 0:
            msg = "⚠️ 柜内商品已全部售罄，请及时补货！"
            msg_1 = "柜内商品已全部售罄，请及时补货！"
            # 既可以用 setPlainText（覆盖），也可以 append（接在后面）：
            self._info.append(f"\n{msg}")
            self._speak(msg_1)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = VisualApp()
    window.show()
    sys.exit(app.exec_())