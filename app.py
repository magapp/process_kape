import os
import subprocess
import time
from flask import Flask, render_template, request, jsonify, send_from_directory, Response, stream_with_context
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_DIR = "downloaded"
RESULT_DIR = "result"
LOCK_FILE = "downloaded/run.lock"
ALLOWED_EXTENSIONS = {"zip"}

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULT_DIR, exist_ok=True)
os.makedirs("temporary_processing", exist_ok=True)


def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def get_lock_info():
    if not os.path.exists(LOCK_FILE):
        return None
    age_seconds = int(time.time() - os.path.getmtime(LOCK_FILE))
    hours, remainder = divmod(age_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours > 0:
        age_str = f"{hours}h {minutes}m {seconds}s"
    elif minutes > 0:
        age_str = f"{minutes}m {seconds}s"
    else:
        age_str = f"{seconds}s"
    return age_str


def get_result_files():
    if not os.path.isdir(RESULT_DIR):
        return []
    entries = []
    for name in sorted(os.listdir(RESULT_DIR)):
        path = os.path.join(RESULT_DIR, name)
        if os.path.isfile(path):
            size = os.path.getsize(path)
            entries.append({"name": name, "size": size})
    return entries


@app.route("/")
def index():
    lock_age = get_lock_info()
    result_files = get_result_files()
    return render_template("index.html", locked=lock_age is not None, lock_age=lock_age, result_files=result_files)


@app.route("/result/<path:filename>")
def download_result(filename):
    return send_from_directory(RESULT_DIR, filename, as_attachment=True)


@app.route("/upload", methods=["POST"])
def upload():
    files = request.files.getlist("files")

    if not files or all(f.filename == "" for f in files):
        return jsonify({"error": "No files selected"}), 400

    saved = []
    errors = []

    for f in files:
        if f and allowed_file(f.filename):
            filename = secure_filename(f.filename)
            dest = os.path.join(UPLOAD_DIR, filename)
            f.save(dest)
            saved.append(filename)
        else:
            errors.append(f.filename)

    return jsonify({"saved": saved, "errors": errors})


LOG_FILE = "temporary_processing/run.log"


@app.route("/log/stream")
def log_stream():
    def generate():
        with open(LOG_FILE, "a"):  # create if missing
            pass
        with open(LOG_FILE, "r") as f:
            f.seek(0, 2)  # start from end of file
            while os.path.exists(LOCK_FILE):
                line = f.readline()
                if line:
                    yield f"data: {line.rstrip()}\n\n"
                else:
                    time.sleep(0.5)
            # drain any remaining lines after lock disappears
            for line in f:
                yield f"data: {line.rstrip()}\n\n"
            yield "event: done\ndata: \n\n"

    return Response(stream_with_context(generate()), mimetype="text/event-stream",
                    headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@app.route("/process", methods=["POST"])
def process():
    if os.path.exists(LOCK_FILE):
        return jsonify({"error": "Already running"}), 409

    script = os.path.join(os.path.dirname(__file__), "bin", "process_kape.sh")
    subprocess.Popen(
        ["bash", script, UPLOAD_DIR, "temporary_processing", RESULT_DIR],
        start_new_session=True,
    )
    return jsonify({"started": True})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
