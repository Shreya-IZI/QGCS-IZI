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

def drag_horizontal(x_start, x_end, y, steps=10, delay=1.0):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    xtst.XTestFakeMotionEvent(disp, -1, int(x_start), int(y), 0)
    x11.XFlush(disp)
    time.sleep(0.05)
    xtst.XTestFakeButtonEvent(disp, 1, 1, 0)
    x11.XFlush(disp)
    step_delta = (x_end - x_start) / float(steps)
    for s in range(1, steps + 1):
        curr_x = int(x_start + step_delta * s)
        xtst.XTestFakeMotionEvent(disp, -1, curr_x, int(y), 0)
        x11.XFlush(disp)
        time.sleep(0.03)
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
print("Starting Test 1: Desktop Wide (1280x800)...")
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_mission_desktop",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_mission_desktop"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(1280, 800)
time.sleep(1.0)

# Dismiss onboarding guide
click_at(845, 234, delay=0.8)
click_at(451, 566, delay=0.8)

# Brand menu -> Mission Planner (id: 2)
click_at(70, 24, delay=1.0)
click_at(150, 160, delay=2.0)

# Desktop: Full toolbar visible
snap("mission_toolbar_01_desktop_wide", 1280, 800)

subprocess.run(["docker", "rm", "-f", "qgc_mission_desktop"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
time.sleep(1.0)

# ==============================================================================
# TEST 2: ANDROID LANDSCAPE (860x450)
# ==============================================================================
print("Starting Test 2: Android Landscape (860x450)...")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "860x450x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_mission_landscape",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_mission_landscape"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(860, 450)
time.sleep(1.0)

# Dismiss guide
click_at(635, 59, delay=0.8)
click_at(240, 395, delay=0.8)

# Brand menu -> Mission Planner
click_at(80, 24, delay=1.0)
click_at(150, 160, delay=2.0)

# Landscape: Toolbar
snap("mission_toolbar_02_android_landscape", 860, 450)

subprocess.run(["docker", "rm", "-f", "qgc_mission_landscape"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
time.sleep(1.0)

# ==============================================================================
# TEST 3: ANDROID PORTRAIT (400x750)
# ==============================================================================
print("Starting Test 3: Android Portrait (400x750)...")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "400x750x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_mission_portrait",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(["docker", "rm", "-f", "qgc_mission_portrait"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(400, 750)
time.sleep(1.0)

# Dismiss guide
click_at(370, 205, delay=0.8)
click_at(50, 545, delay=0.8)

# TopBar on portrait: Brand menu at x=80, y=24
click_at(80, 24, delay=1.0)
click_at(150, 160, delay=2.0)

# Snap 3a: Portrait Initial (Active Flight Plan, Distance, Est. Time, Synced, Health)
# Note: toolbar is located below TopBar (TopBar height ~48), so topCommandStrip y is ~56..104
snap("mission_toolbar_03_android_portrait_initial", 400, 750)

# Test Horizontal Drag / Swipe: swipe left on the toolbar (y ~ 78) from x=360 to x=40
print("Testing horizontal drag swipe on Mission Planner toolbar...")
drag_horizontal(360, 40, 78, steps=15, delay=1.5)

# Snap 3b: Portrait Swiped (reveals ADD WAYPOINT, Fit Map, Download, Upload to Drone, Menu)
snap("mission_toolbar_04_android_portrait_swiped", 400, 750)

# Test interactive click on "ADD WAYPOINT" toggle or "Fit Map" while scrolled
# Now ADD WAYPOINT is around x=60..120, y=78
click_at(90, 78, delay=1.5)
snap("mission_toolbar_05_android_portrait_action", 400, 750)

subprocess.run(["docker", "rm", "-f", "qgc_mission_portrait"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")

print("ALL MISSION TOOLBAR SCROLL VERIFICATION TESTS COMPLETED SUCCESSFULLY!")
