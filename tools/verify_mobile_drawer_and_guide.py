import subprocess, time, os, ctypes
from PIL import Image

DISP = ":88"
WIDTH = 860
HEIGHT = 450

os.environ["DISPLAY"] = DISP
os.system(f"rm -f /tmp/.X88-lock /tmp/.X11-unix/X88")
xvfb = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", f"{WIDTH}x{HEIGHT}x24"])
time.sleep(1.5)

x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
xtst = ctypes.cdll.LoadLibrary("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
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
    print(f"Captured: {dest}")

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_drawer_test",
    "--net=host",
    "-u", "1000:1000",
    "-v", f"{os.getcwd()}:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", "/project/build-desktop/Release/QGroundControl",
    "qgc-ubuntu-2204-docker:latest"
]

subprocess.run(["docker", "rm", "-f", "qgc_drawer_test"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(6)
resize_windows(WIDTH, HEIGHT)
time.sleep(1.0)

# 1. Snapshot of Onboarding Guide (Step 1)
snap("mobile_drawer_01_onboarding_guide")

# Tap "NEXT →" button in footer (around center x=610, y=410)
click_at(620, 400, delay=1.0)
snap("mobile_drawer_01b_onboarding_step2")

# Tap "✕" close button in top right of card (around x=635, y=55)
click_at(635, 55, delay=1.0)

# 2. Snapshot after dismissing guide - full map view with hamburger button visible in TopBar
snap("mobile_drawer_02_map_view_closed")

# 3. Tap the hamburger button in TopBar (top-left: x=24, y=22)
click_at(24, 22, delay=1.0)

# 4. Snapshot of drawer open over map
snap("mobile_drawer_03_drawer_open")

# 5. Tap "Camera" in the drawer (around x=80, y=140)
click_at(80, 140, delay=1.5)

# 6. Snapshot of Camera view
snap("mobile_drawer_04_camera_view")

subprocess.run(["docker", "rm", "-f", "qgc_drawer_test"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X88-lock /tmp/.X11-unix/X88")
print("Verification complete!")
