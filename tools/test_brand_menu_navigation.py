import subprocess, time, os, ctypes
from PIL import Image

DISP = ":92"
os.environ["DISPLAY"] = DISP
os.system(f"rm -f /tmp/.X92-lock /tmp/.X11-unix/X92")
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
    "--name", "qgc_brand_nav_app",
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

# Item 1: Mission Planner from Brand Menu
# Open brand menu (click at 80, 24)
click_at(80, 24, delay=0.8)
# Click Mission Planner in brand popup (x=190, y=171)
click_at(190, 171, delay=2.0)
snap("sw_brand_nav_01_mission_planner")

# Item 2: Vehicle Parameters from Brand Menu
click_at(80, 24, delay=0.8)
# Click Vehicle Parameters (x=190, y=215)
click_at(190, 215, delay=2.0)
snap("sw_brand_nav_02_parameters")

# Item 3: Vehicle Setup from Brand Menu
click_at(80, 24, delay=0.8)
# Click Vehicle Setup (x=190, y=259)
click_at(190, 259, delay=2.0)
snap("sw_brand_nav_03_vehicle_setup")

# Item 4: Flight Logs from Brand Menu
click_at(80, 24, delay=0.8)
# Click Flight Logs (x=190, y=347)
click_at(190, 347, delay=2.0)
snap("sw_brand_nav_04_flight_logs")

# Item 5: System Settings from Brand Menu
click_at(80, 24, delay=0.8)
# Click System Settings (x=190, y=391)
click_at(190, 391, delay=2.0)
snap("sw_brand_nav_05_settings")

# Item 6: Flight Operations from Brand Menu
click_at(80, 24, delay=0.8)
# Click Flight Operations (x=190, y=127)
click_at(190, 127, delay=2.0)
snap("sw_brand_nav_06_flight_operations")

subprocess.run(["docker", "rm", "-f", "qgc_brand_nav_app"])
xvfb.terminate()
os.system(f"rm -f /tmp/.X92-lock /tmp/.X11-unix/X92")
print("BRAND MENU NAVIGATION TEST COMPLETED!")
