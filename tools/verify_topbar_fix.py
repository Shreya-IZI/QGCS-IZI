import subprocess, time, os, ctypes
from PIL import Image

DISP = ":87"
os.environ["DISPLAY"] = DISP
os.system(f"rm -f /tmp/.X87-lock /tmp/.X11-unix/X87")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
time.sleep(1.5)

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]

def click_at(x, y, delay=1.0):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    xtst.XTestFakeMotionEvent(disp, -1, int(x), int(y), 0)
    x11.XFlush(disp)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(disp, 1, 1, 0)
    x11.XFlush(disp)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(disp, 1, 0, 0)
    x11.XFlush(disp)
    x11.XCloseDisplay(disp)
    time.sleep(delay)

def snap(name):
    out = f"/tmp/{name}.xwd"
    subprocess.run(f"xwd -display {DISP} -root -silent -out {out}", shell=True)
    with open(out, 'rb') as f:
        f.seek(os.path.getsize(out) - (1280 * 800 * 4))
        raw = f.read(1280 * 800 * 4)
    img = Image.frombytes('RGB', (1280, 800), raw, 'raw', 'BGRX')
    dest = f"/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6/{name}.png"
    img.save(dest)
    print(f"Saved {name}.png")

appimage = "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-company/QGroundControl-x86_64.AppImage"
container_name = "qgc_verify_topbar_app"
subprocess.run(f"docker rm -f {container_name} 2>/dev/null", shell=True)

docker_cmd = [
    "docker", "run", "-d",
    "--name", container_name,
    "--net=host",
    "-u", "1000:1000",
    "-v", f"{appimage}:/app.AppImage",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", "/app.AppImage",
    "qgc-ubuntu-2204-docker:latest",
    "--appimage-extract-and-run"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
click_at(834, 377, delay=0.5)

# Open Brand Menu (where TopBar.qml line 162 resides: "IZI Enterprise GCS" text in header)
print("[TEST] Opening IZI brand menu...")
click_at(80, 24, delay=1.0)
snap("sw_topbar_fix_brand_menu")

# Close popup
click_at(600, 300, delay=0.8)

# Check docker logs
logs = subprocess.run(["docker", "logs", container_name], capture_output=True, text=True)
print("=== CAPTURED DOCKER STDERR ===")
print(logs.stderr)

# Check specifically for the TopBar warning
warning_found = "Unable to assign [undefined] to double" in logs.stderr
print(f"Warning 'Unable to assign [undefined] to double' found: {warning_found}")

subprocess.run(["docker", "rm", "-f", container_name])
xvfb.terminate()
os.system(f"rm -f /tmp/.X87-lock /tmp/.X11-unix/X87")

if warning_found:
    print("[RESULT] FAIL: Warning still present")
    exit(1)
else:
    print("[RESULT] PASS: Warning is completely eliminated!")
    exit(0)
