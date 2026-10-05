import subprocess, time, os, ctypes
from PIL import Image

DISP = ":89"
WIDTH = 860
HEIGHT = 450

os.environ["DISPLAY"] = DISP
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", f"{WIDTH}x{HEIGHT}x24"])
time.sleep(1.5)

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]

x11.XDefaultRootWindow.restype = ctypes.c_ulong
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XQueryTree.restype = ctypes.c_int
x11.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
x11.XMoveResizeWindow.restype = ctypes.c_int
x11.XMoveResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]

def resize_windows(w, h):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    root_win = x11.XDefaultRootWindow(disp)
    root_ret = ctypes.c_ulong()
    parent_ret = ctypes.c_ulong()
    children_ret = ctypes.POINTER(ctypes.c_ulong)()
    nchildren = ctypes.c_uint()
    x11.XQueryTree(disp, root_win, ctypes.byref(root_ret), ctypes.byref(parent_ret), ctypes.byref(children_ret), ctypes.byref(nchildren))
    for i in range(nchildren.value):
        child = children_ret[i]
        x11.XMoveResizeWindow(disp, child, 0, 0, int(w), int(h))
    x11.XFlush(disp)
    x11.XCloseDisplay(disp)

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
        f.seek(os.path.getsize(out) - (WIDTH * HEIGHT * 4))
        raw = f.read(WIDTH * HEIGHT * 4)
    img = Image.frombytes('RGB', (WIDTH, HEIGHT), raw, 'raw', 'BGRX')
    dest = f"/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6/{name}.png"
    img.save(dest)
    print(f"Saved {name}.png ({WIDTH}x{HEIGHT})")

binary = "/project/build/Release/QGroundControl"
docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_mobile_ui_test",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project/source",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-company:/project/build",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(WIDTH, HEIGHT)
time.sleep(1.0)

# Dismiss any initial modal/connect prompt if present
click_at(WIDTH // 2, HEIGHT // 2, delay=0.5)

# Snap 1: Flight Operations (Default Map / Dashboard)
snap("mobile_01_flight_ops")

# Switch to CAM view (click "CAM" pill in view switcher: x=235, y=65)
click_at(235, 65, delay=1.0)
snap("mobile_02_camera_view")

# Open Brand Menu -> Parameters (tab index 6)
click_at(50, 24, delay=0.6)
# Click "Parameters" in menu (around y=215)
click_at(180, 215, delay=1.2)
snap("mobile_03_parameters_view")

# Toggle Groups in Parameters
click_at(80, 105, delay=0.8)
snap("mobile_04_parameters_groups_toggle")

# Open Brand Menu -> Flight Logs (tab index 4)
click_at(50, 24, delay=0.6)
# Click "Flight Logs" in menu (around y=345)
click_at(180, 345, delay=1.2)
snap("mobile_05_flight_logs_view")

# Open Sidebar drawer (click hamburger icon at top-left of sidebar rail: x=25, y=65)
click_at(25, 65, delay=0.8)
snap("mobile_06_sidebar_overlay_drawer")

subprocess.run(["docker", "rm", "-f", "qgc_mobile_ui_test"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
print("ALL MOBILE SNAPSHOTS CAPTURED!")
