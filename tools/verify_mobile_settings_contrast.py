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

def snap(name, w=860, h=450):
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
docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_mobile_contrast_test2",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/tmp",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]

subprocess.run(["docker", "rm", "-f", "qgc_mobile_contrast_test2"], capture_output=True)
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(WIDTH, HEIGHT)
time.sleep(1.0)

# Dismiss Operator Guide
click_at(635, 59, delay=0.8)
click_at(240, 395, delay=0.8)

# Brand menu at x=80, y=24
click_at(80, 24, delay=1.0)
# Click "System Settings" (item 7 around y=380, x=150)
click_at(150, 380, delay=2.0)

# Snap mobile settings with drawer closed
snap("mobile_settings_02_full_view", WIDTH, HEIGHT)

subprocess.run(["docker", "rm", "-f", "qgc_mobile_contrast_test2"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X89-lock /tmp/.X11-unix/X89")
print("MOBILE FULL VIEW TEST COMPLETE!")
