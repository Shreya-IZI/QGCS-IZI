import subprocess, time, os, ctypes
from PIL import Image

DISP = ":89"
os.environ["DISPLAY"] = DISP

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

def snap(name, w, h):
    out = f"/tmp/{name}.xwd"
    subprocess.run(f"xwd -display {DISP} -root -silent -out {out}", shell=True)
    with open(out, 'rb') as f:
        f.seek(os.path.getsize(out) - (w * h * 4))
        raw = f.read(w * h * 4)
    img = Image.frombytes('RGB', (w, h), raw, 'raw', 'BGRX')
    dest = f"/home/izi-system/.gemini/antigravity/brain/1ca0d453-7e62-4176-bc1d-d749787210d6/{name}.png"
    img.save(dest)
    print(f"Saved {dest} ({w}x{h})")

binary = "/project/build-desktop/Release/QGroundControl"

# ==============================================================================
# TEST 1: DESKTOP WIDE (1280x800)
# ==============================================================================
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_tabs_desktop",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_tabs_desktop"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(1280, 800)
time.sleep(1.0)

# Dismiss guide
click_at(845, 234, delay=0.8)
click_at(451, 566, delay=0.8)

# Brand menu -> Settings
click_at(70, 24, delay=1.0)
click_at(150, 380, delay=2.0)

# Desktop: Data Logging Tab Active
snap("tab_scroll_01_desktop_wide", 1280, 800)

subprocess.run(["docker", "rm", "-f", "qgc_tabs_desktop"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
time.sleep(1.0)

# ==============================================================================
# TEST 2: ANDROID LANDSCAPE (860x450)
# ==============================================================================
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "860x450x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_tabs_landscape",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_tabs_landscape"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(860, 450)
time.sleep(1.0)

# Dismiss guide
click_at(635, 59, delay=0.8)
click_at(240, 395, delay=0.8)

# Brand menu -> Settings
click_at(80, 24, delay=1.0)
click_at(150, 380, delay=2.0)

# Landscape: Tabs Row
snap("tab_scroll_02_android_landscape", 860, 450)

subprocess.run(["docker", "rm", "-f", "qgc_tabs_landscape"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
time.sleep(1.0)

# ==============================================================================
# TEST 3: ANDROID PORTRAIT (400x750)
# ==============================================================================
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "400x750x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_tabs_portrait",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_tabs_portrait"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(400, 750)
time.sleep(1.0)

# Dismiss guide (centered in 400x750: card width ~376, height ~380)
click_at(370, 205, delay=0.8) # close button
click_at(50, 545, delay=0.8)  # skip button

# TopBar on portrait: Brand menu at x=80, y=24
click_at(80, 24, delay=1.0)
click_at(150, 380, delay=2.0)

# Snap 3a: Portrait Initial (DATA LOGGING visible)
snap("tab_scroll_03_android_portrait_initial", 400, 750)

# Click NETWORK & LINKS (around x=200, y=98)
click_at(200, 98, delay=1.5)
snap("tab_scroll_04_android_portrait_network", 400, 750)

# Drag / swipe flickable from right to left (from x=350 to x=50 at y=98)
disp = x11.XOpenDisplay(DISP.encode('utf-8'))
xtst.XTestFakeMotionEvent(disp, -1, 350, 98, 0)
x11.XFlush(disp)
time.sleep(0.05)
xtst.XTestFakeButtonEvent(disp, 1, 1, 0) # mouse down
x11.XFlush(disp)
for step in range(350, 40, -30):
    xtst.XTestFakeMotionEvent(disp, -1, step, 98, 0)
    x11.XFlush(disp)
    time.sleep(0.02)
xtst.XTestFakeButtonEvent(disp, 1, 0, 0) # mouse up
x11.XFlush(disp)
x11.XCloseDisplay(disp)
time.sleep(1.5)

# Snap 3b: Portrait Swiped (OFFLINE MAPS revealed)
snap("tab_scroll_05_android_portrait_swiped", 400, 750)

subprocess.run(["docker", "rm", "-f", "qgc_tabs_portrait"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")

print("ALL TAB SCROLL VERIFICATION TESTS COMPLETED!")
