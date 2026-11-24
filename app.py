# app.py
import os
import re
import time
import threading
import requests
from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

LOGS = []
LOG_LOCK = threading.Lock()


def log(msg):
    with LOG_LOCK:
        LOGS.append(f"[{time.strftime('%H:%M:%S')}] {msg}")
        if len(LOGS) > 500:
            LOGS.pop(0)


class FBSession:
    def __init__(self, cookie):
        self.s = requests.Session()
        self.s.headers.update({"User-Agent": UA, "Cookie": cookie})
        self.cookie = cookie

    def _get_tokens(self):
        r = self.s.get("https://www.facebook.com/me", timeout=20)
        html = r.text
        fb_dtsg = re.search(r'"DTSGInitialData".*?"token":"(.*?)"', html)
        jazoest = re.search(r'name="jazoest" value="(\d+)"', html)
        lsd = re.search(r'"LSD",\[\],{"token":"(.*?)"}', html)
        return {
            "fb_dtsg": fb_dtsg.group(1) if fb_dtsg else None,
            "jazoest": jazoest.group(1) if jazoest else None,
            "lsd": lsd.group(1) if lsd else None,
        }

    def check_live(self):
        r = self.s.get("https://www.facebook.com/me", allow_redirects=False, timeout=20)
        return r.status_code == 200

    def get_uid(self):
        r = self.s.get("https://www.facebook.com/me", timeout=20)
        m = re.search(r'"USER_ID":"(\d+)"', r.text)
        return m.group(1) if m else None

    def post_text(self, text):
        tokens = self._get_tokens()
        if not tokens["fb_dtsg"]:
            return {"ok": False, "error": "no fb_dtsg — cookie có thể chết"}
        data = {
            "fb_dtsg": tokens["fb_dtsg"],
            "jazoest": tokens["jazoest"],
            "lsd": tokens["lsd"],
            "message": text,
            "source": "composer",
        }
        r = self.s.post("https://www.facebook.com/api/graphql/", data=data, timeout=20)
        return {"ok": True, "status": r.status_code, "body": r.text[:500]}

    def report_post(self, post_id, category="SPAM"):
        tokens = self._get_tokens()
        data = {
            "fb_dtsg": tokens["fb_dtsg"],
            "jazoest": tokens["jazoest"],
            "lsd": tokens["lsd"],
            "target_id": post_id,
            "report_category": category,
        }
        r = self.s.post("https://www.facebook.com/api/graphql/", data=data, timeout=20)
        return {"ok": True, "status": r.status_code, "body": r.text[:500]}


PAGE = """
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<title>FB Burner</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #0f1419; color: #e6e6e6; margin: 0; padding: 20px; }
  .container { max-width: 960px; margin: 0 auto; }
  h1 { font-size: 22px; margin: 0 0 20px; color: #ff6b6b; letter-spacing: 1px; }
  .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
  .tab { padding: 10px 20px; background: #1a2332; border: none; color: #888; cursor: pointer; border-radius: 6px 6px 0 0; font-size: 14px; }
  .tab.active { background: #2a3a52; color: #fff; }
  .panel { display: none; background: #1a2332; padding: 20px; border-radius: 0 6px 6px 6px; }
  .panel.active { display: block; }
  label { display: block; font-size: 12px; color: #8a9bb0; margin: 12px 0 6px; text-transform: uppercase; letter-spacing: 1px; }
  input, textarea, select { width: 100%; padding: 10px; background: #0f1419; border: 1px solid #2a3a52; border-radius: 6px; color: #e6e6e6; font-size: 14px; font-family: inherit; }
  textarea { resize: vertical; min-height: 80px; }
  button.action { margin-top: 16px; padding: 12px 24px; background: #ff6b6b; border: none; color: #fff; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 600; }
  button.action:hover { background: #ff5252; }
  button.action:disabled { background: #444; cursor: not-allowed; }
  #logbox { background: #0a0f14; padding: 12px; border-radius: 6px; height: 320px; overflow-y: auto; font-family: 'Consolas', monospace; font-size: 12px; line-height: 1.6; white-space: pre-wrap; }
  .status { padding: 8px 12px; border-radius: 6px; margin-top: 12px; font-size: 13px; }
  .ok { background: #1a3d2a; color: #6bff9e; }
  .err { background: #3d1a1a; color: #ff6b6b; }
</style>
</head>
<body>
<div class="container">
  <h1>FB BURNER</h1>
  <div class="tabs">
    <button class="tab active" data-tab="session">Session</button>
    <button class="tab" data-tab="post">Post</button>
    <button class="tab" data-tab="report">Report</button>
    <button class="tab" data-tab="log">Log</button>
  </div>

  <div class="panel active" id="panel-session">
    <label>Cookie nick mục tiêu</label>
    <textarea id="cookie" placeholder="paste cookie vào đây..."></textarea>
    <button class="action" onclick="checkSession()">Check Session</button>
    <div id="session-result"></div>
  </div>

  <div class="panel" id="panel-post">
    <label>Nội dung post (từ nick mục tiêu)</label>
    <textarea id="post-content" placeholder="nội dung vi phạm..."></textarea>
    <button class="action" onclick="doPost()">Đăng bài</button>
    <div id="post-result"></div>
  </div>

  <div class="panel" id="panel-report">
    <label>Post ID cần report</label>
    <input id="post-id" placeholder="vd: 1234567890">
    <label>Category</label>
    <select id="report-cat">
      <option value="SPAM">SPAM</option>
      <option value="VIOLENCE">VIOLENCE</option>
      <option value="NUDITY">NUDITY</option>
      <option value="HATE_SPEECH">HATE_SPEECH</option>
      <option value="IMPERSONATION">IMPERSONATION</option>
    </select>
    <label>Cookie clone (dùng để report)</label>
    <textarea id="clone-cookie" placeholder="cookie clone..."></textarea>
    <button class="action" onclick="doReport()">Report</button>
    <div id="report-result"></div>
  </div>

  <div class="panel" id="panel-log">
    <label>Log</label>
    <div id="logbox"></div>
  </div>
</div>

<script>
const tabs = document.querySelectorAll('.tab');
const panels = document.querySelectorAll('.panel');
tabs.forEach(t => t.onclick = () => {
  tabs.forEach(x => x.classList.remove('active'));
  panels.forEach(p => p.classList.remove('active'));
  t.classList.add('active');
  document.getElementById('panel-' + t.dataset.tab).classList.add('active');
});

function showResult(id, ok, msg) {
  const el = document.getElementById(id);
  el.className = 'status ' + (ok ? 'ok' : 'err');
  el.textContent = msg;
}

async function api(path, body) {
  const r = await fetch(path, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body) });
  return r.json();
}

async function checkSession() {
  const cookie = document.getElementById('cookie').value.trim();
  if (!cookie) return showResult('session-result', false, 'cookie trống');
  showResult('session-result', true, 'đang check...');
  const res = await api('/check', {cookie});
  showResult('session-result', res.ok, res.msg);
}

async function doPost() {
  const cookie = document.getElementById('cookie').value.trim();
  const content = document.getElementById('post-content').value.trim();
  if (!cookie || !content) return showResult('post-result', false, 'thiếu cookie hoặc nội dung');
  showResult('post-result', true, 'đang đăng...');
  const res = await api('/post', {cookie, content});
  showResult('post-result', res.ok, res.msg);
}

async function doReport() {
  const cloneCookie = document.getElementById('clone-cookie').value.trim();
  const postId = document.getElementById('post-id').value.trim();
  const cat = document.getElementById('report-cat').value;
  if (!cloneCookie || !postId) return showResult('report-result', false, 'thiếu dữ liệu');
  showResult('report-result', true, 'đang report...');
  const res = await api('/report', {cookie: cloneCookie, post_id: postId, category: cat});
  showResult('report-result', res.ok, res.msg);
}

async function refreshLog() {
  const r = await fetch('/logs');
  const d = await r.json();
  const box = document.getElementById('logbox');
  box.textContent = d.logs.join('\\n') || '(empty)';
  box.scrollTop = box.scrollHeight;
}
setInterval(refreshLog, 1500);
refreshLog();
</script>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(PAGE)


@app.route("/check", methods=["POST"])
def check():
    d = request.get_json()
    sess = FBSession(d["cookie"])
    try:
        if sess.check_live():
            uid = sess.get_uid()
            log(f"check: LIVE uid={uid}")
            return jsonify({"ok": True, "msg": f"LIVE — UID: {uid}"})
        log("check: DEAD")
        return jsonify({"ok": False, "msg": "cookie chết"})
    except Exception as e:
        log(f"check error: {e}")
        return jsonify({"ok": False, "msg": f"lỗi: {e}"})


@app.route("/post", methods=["POST"])
def do_post():
    d = request.get_json()
    sess = FBSession(d["cookie"])
    try:
        res = sess.post_text(d["content"])
        log(f"post: {res.get('status')} {res.get('body','')[:120]}")
        if res.get("ok"):
            return jsonify({"ok": True, "msg": f"đã gửi (HTTP {res.get('status')}) — check profile để lấy post ID"})
        return jsonify({"ok": False, "msg": res.get("error", "lỗi")})
    except Exception as e:
        log(f"post error: {e}")
        return jsonify({"ok": False, "msg": f"lỗi: {e}"})


@app.route("/report", methods=["POST"])
def do_report():
    d = request.get_json()
    sess = FBSession(d["cookie"])
    try:
        res = sess.report_post(d["post_id"], d["category"])
        log(f"report {d['post_id']} [{d['category']}]: {res.get('status')}")
        return jsonify({"ok": True, "msg": f"đã report (HTTP {res.get('status')})"})
    except Exception as e:
        log(f"report error: {e}")
        return jsonify({"ok": False, "msg": f"lỗi: {e}"})


@app.route("/logs")
def logs():
    with LOG_LOCK:
        return jsonify({"logs": list(LOGS)})


if __name__ == "__main__":
    print("[*] FB Burner running: http://127.0.0.1:5000")
    app.run(host="127.0.0.1", port=5000, debug=False)