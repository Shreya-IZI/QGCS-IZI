import subprocess, time, os, ctypes
from PIL import Image

DISP = ":90"
os.environ["DISPLAY"] = DISP
os.system(f"rm -f /tmp/.X90-lock /tmp/.X11-unix/X90")
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
docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_settings_tab_test",
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

# Open Settings via Brand Menu (click at 80, 24 then 190, 391)
click_at(80, 24, delay=0.8)
click_at(190, 391, delay=2.0)
snap("sw_settings_01_telemetry")

# Click NETWORK & LINKS at x=800, y=107
click_at(800, 107, delay=1.5)
snap("sw_settings_02_network")

# Click OFFLINE MAPS at x=930, y=107
click_at(930, 107, delay=1.5)
snap("sw_settings_03_offline_maps")

# Click DATA LOGGING at x=674, y=107
click_at(674, 107, delay=1.5)
snap("sw_settings_04_data_logging")

subprocess.run(["docker", "rm", "-f", "qgc_settings_tab_test"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X90-lock /tmp/.X11-unix/X90")
print("SETTINGS SUB-TABS TEST COMPLETED!")
