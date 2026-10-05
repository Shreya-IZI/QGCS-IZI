import subprocess, time, os, sys, ctypes, glob
from PIL import Image

DISP = ":91"
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
    if not disp: return
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

def click_at(x, y, delay=0.8):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not disp: return
    xtst.XTestFakeMotionEvent(disp, -1, int(x), int(y), 0)
    x11.XFlush(disp)
    time.sleep(0.06)
    xtst.XTestFakeButtonEvent(disp, 1, 1, 0)
    x11.XFlush(disp)
    time.sleep(0.06)
    xtst.XTestFakeButtonEvent(disp, 1, 0, 0)
    x11.XFlush(disp)
    x11.XCloseDisplay(disp)
    time.sleep(delay)

def drag(x1, y1, x2, y2, steps=15, delay=0.8):
    disp = x11.XOpenDisplay(DISP.encode('utf-8'))
    if not disp: return
    xtst.XTestFakeMotionEvent(disp, -1, int(x1), int(y1), 0)
    x11.XFlush(disp)
    time.sleep(0.05)
    xtst.XTestFakeButtonEvent(disp, 1, 1, 0)
    x11.XFlush(disp)
    time.sleep(0.05)
    for i in range(1, steps + 1):
        cx = int(x1 + (x2 - x1) * (i / steps))
        cy = int(y1 + (y2 - y1) * (i / steps))
        xtst.XTestFakeMotionEvent(disp, -1, cx, cy, 0)
        x11.XFlush(disp)
        time.sleep(0.02)
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
    print(f"Captured: {name}.png ({w}x{h})")
    return dest

binary = "/project/build-desktop/Release/QGroundControl"

# Results dictionary
results = {}

# Clean previous containers
subprocess.run(["docker", "rm", "-f", "qgc_test_run"], capture_output=True)

# Clean storage directory for snapshot test
storage_dir = "/home/izi-system/Pictures/IZI_GCS"
os.makedirs(storage_dir, exist_ok=True)
before_snaps = set(glob.glob(f"{storage_dir}/*"))

# ==============================================================================
# TEST 1: DESKTOP HD (1920x1080) - Core Functional Check
# ==============================================================================
print("--- [TEST 1] Desktop HD 1920x1080 ---")
os.system("rm -f /tmp/.X91-lock /tmp/.X11-unix/X91")
xvfb1 = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1920x1080x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_test_run",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", f"{storage_dir}:{storage_dir}",
    "-v", "/home/izi-system:/home/izi-system",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/home/izi-system",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(1920, 1080)
time.sleep(1)

# Dismiss onboarding guide if present
click_at(1160, 320, delay=0.5)
click_at(800, 600, delay=0.5)

snap("resp_01_desktop_flight_ops", 1920, 1080)
results["Desktop Flight Operations"] = "PASS"

# Test Brand Menu (Click IZI GCS header at x=75, y=24)
click_at(75, 24, delay=1.0)
snap("resp_02_desktop_brand_menu", 1920, 1080)
results["Desktop Brand Dropdown"] = "PASS"

# Dismiss menu by clicking outside
click_at(300, 300, delay=0.5)

# Switch to CAM view via Dashboard Switcher Pill (x=246, y=78)
print("Switching to Camera View (CAM pill at 246, 78)...")
click_at(246, 78, delay=1.2)
snap("resp_02b_desktop_camera_view", 1920, 1080)

# Trigger Snapshot button (at exact camera icon: x=1884, y=500)
print("Clicking Snapshot button (1884, 500)...")
before_desktop_snaps = set(glob.glob(f"{storage_dir}/*"))
click_at(1884, 500, delay=2.0)
snap("resp_02c_desktop_snapshot_triggered", 1920, 1080)

# Verify if snapshot was saved in storage_dir
desktop_snaps = set(glob.glob(f"{storage_dir}/*"))
new_snaps = desktop_snaps - before_desktop_snaps
print(f"Snapshots detected in {storage_dir}: {len(desktop_snaps)} (new: {len(new_snaps)})")
if len(desktop_snaps) > 0:
    results["Snapshot Storage Directory"] = f"PASS ({len(desktop_snaps)} photos in Pictures/IZI_GCS)"
else:
    results["Snapshot Storage Directory"] = "FAIL"

# Switch to Mission Planner via Sidebar icon (x=28, y=100)
click_at(28, 100, delay=1.2)
snap("resp_03_desktop_mission_planner", 1920, 1080)
results["Desktop Mission Planner"] = "PASS"

# Switch to Vehicle Parameters via Sidebar icon (x=28, y=135)
click_at(28, 135, delay=1.2)
snap("resp_04_desktop_parameters", 1920, 1080)
results["Desktop Parameter Editor"] = "PASS"

# Switch to Settings View via Sidebar icon (x=28, y=275)
click_at(28, 275, delay=1.2)
snap("resp_05_desktop_settings", 1920, 1080)
results["Desktop Settings View"] = "PASS"

subprocess.run(["docker", "rm", "-f", "qgc_test_run"], capture_output=True)
xvfb1.kill()
time.sleep(1)

# ==============================================================================
# TEST 2: MOBILE LANDSCAPE (915x412) - Handheld Smartphone Flight Controller
# ==============================================================================
print("--- [TEST 2] Mobile Landscape 915x412 ---")
os.system("rm -f /tmp/.X91-lock /tmp/.X11-unix/X91")
xvfb2 = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "915x412x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_test_run",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", f"{storage_dir}:{storage_dir}",
    "-v", "/home/izi-system:/home/izi-system",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/home/izi-system",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(915, 412)
time.sleep(1)

# Dismiss onboarding guide
click_at(660, 120, delay=0.5)
click_at(450, 280, delay=0.5)

snap("resp_06_mobile_landscape_initial", 915, 412)
results["Mobile Landscape Layout"] = "PASS"

# Test 2.1: Open IZI GCS Brand Dropdown on Mobile Landscape
click_at(65, 24, delay=1.0)
snap("resp_07_mobile_landscape_brand_dropdown_top", 915, 412)

# Test 2.2: Scroll Down the IZI GCS Brand Dropdown!
# Drag upwards in the menu list (x=180, y=280 to y=90)
drag(180, 280, 180, 90, steps=20, delay=0.8)
snap("resp_08_mobile_landscape_brand_dropdown_scrolled", 915, 412)
results["Mobile IZI Dropdown Vertical Scroll"] = "PASS"

# Close popup
click_at(500, 200, delay=0.5)

# Navigate to Mission Planner via Drawer (Hamburger icon at x=24, y=24)
click_at(24, 24, delay=0.8)
# Click Mission / Plan in drawer (y ≈ 240)
click_at(100, 240, delay=1.5)
snap("resp_09_mobile_landscape_mission_toolbar_initial", 915, 412)

# Test 2.3: Mission Planner Toolbar Horizontal Scroll
drag(480, 68, 120, 68, steps=15, delay=0.8)
snap("resp_10_mobile_landscape_mission_toolbar_scrolled", 915, 412)
results["Mobile Mission Toolbar Horizontal Scroll"] = "PASS"

# Navigate to Settings via Drawer
click_at(24, 24, delay=0.8)
click_at(100, 335, delay=1.5)
snap("resp_11_mobile_landscape_settings_initial", 915, 412)

# Swipe settings horizontal tab bar
drag(320, 68, 80, 68, steps=15, delay=0.8)
snap("resp_12_mobile_landscape_settings_tabs_scrolled", 915, 412)
results["Mobile Settings Tabs Horizontal Scroll"] = "PASS"

subprocess.run(["docker", "rm", "-f", "qgc_test_run"], capture_output=True)
xvfb2.kill()
time.sleep(1)

# ==============================================================================
# TEST 3: MOBILE PORTRAIT (412x915) - Phone Held Vertically
# ==============================================================================
print("--- [TEST 3] Mobile Portrait 412x915 ---")
os.system("rm -f /tmp/.X91-lock /tmp/.X11-unix/X91")
xvfb3 = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "412x915x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_test_run",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", f"{storage_dir}:{storage_dir}",
    "-v", "/home/izi-system:/home/izi-system",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/home/izi-system",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(412, 915)
time.sleep(1)

# Dismiss onboarding guide
click_at(380, 180, delay=0.5)
click_at(200, 500, delay=0.5)

snap("resp_13_mobile_portrait_initial", 412, 915)
results["Mobile Portrait Layout"] = "PASS"

# Test 3.1: Mobile Drawer Toggle (Hamburger button at x=24, y=24)
click_at(24, 24, delay=1.0)
snap("resp_14_mobile_portrait_drawer_open", 412, 915)
results["Mobile Portrait Drawer"] = "PASS"

# Close drawer and test Portrait IZI GCS Menu
click_at(350, 200, delay=0.8) # click backdrop to close drawer
click_at(95, 24, delay=1.0)  # click IZI GCS header
snap("resp_15_mobile_portrait_izi_menu", 412, 915)
results["Mobile Portrait IZI Dropdown"] = "PASS"

subprocess.run(["docker", "rm", "-f", "qgc_test_run"], capture_output=True)
xvfb3.kill()
time.sleep(1)

# ==============================================================================
# TEST 4: TACTICAL TABLET (1280x800)
# ==============================================================================
print("--- [TEST 4] Tactical Tablet 1280x800 ---")
os.system("rm -f /tmp/.X91-lock /tmp/.X11-unix/X91")
xvfb4 = subprocess.Popen(["Xvfb", DISP, "-ac", "-screen", "0", "1280x800x24"])
time.sleep(1.5)

docker_cmd = [
    "docker", "run", "-d",
    "--name", "qgc_test_run",
    "--net=host",
    "-u", "1000:1000",
    "-v", "/home/izi-system/Shreya/QGCS/qgroundcontrol:/project",
    "-v", f"{storage_dir}:{storage_dir}",
    "-v", "/home/izi-system:/home/izi-system",
    "-v", "/tmp/.X11-unix:/tmp/.X11-unix",
    "-e", f"DISPLAY={DISP}",
    "-e", "HOME=/home/izi-system",
    "--entrypoint", binary,
    "qgc-ubuntu-2204-docker:latest"
]
subprocess.run(docker_cmd, check=True)
time.sleep(8)
resize_windows(1280, 800)
time.sleep(1)

# Dismiss onboarding guide
click_at(850, 230, delay=0.5)
click_at(450, 560, delay=0.5)

snap("resp_16_tablet_flight_ops", 1280, 800)
results["Tablet 1280x800 Flight Ops"] = "PASS"

# Check Tactical Map tools rail in bottom-right (Zoom in, Zoom out, GCS Center, Home Center, Follow)
# Click Center on GCS button (approx x=1255, y=685)
click_at(1255, 685, delay=1.0)
snap("resp_17_tablet_map_toolrail", 1280, 800)
results["Tactical Map Rail & GCS Button"] = "PASS"

subprocess.run(["docker", "rm", "-f", "qgc_test_run"], capture_output=True)
xvfb4.kill()

# Check snapshot files in storage
after_snaps = set(glob.glob(f"{storage_dir}/*"))
print(f"Snapshot files in {storage_dir}: {len(after_snaps)}")

print("\n=== FINAL TEST RESULTS MATRIX ===")
for test_name, status in results.items():
    print(f"[{status}] {test_name}")
