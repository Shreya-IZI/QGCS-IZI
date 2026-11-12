import sys
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, hex_color):
    shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    cell._tc.get_or_add_tcPr().append(shading_elm)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def set_table_borders(table, color="D1D5DB", sz="4", val="single"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(f'<w:tblBorders {nsdecls("w")}>'
                        f'<w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
                        f'<w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
                        f'<w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
                        f'<w:insideV w:val="none"/>'
                        f'<w:left w:val="none"/>'
                        f'<w:right w:val="none"/>'
                        f'</w:tblBorders>')
    tblPr.append(borders)

def build_document():
    doc = Document()

    # Set margins to 0.75 in
    for section in doc.sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)

    # Styles
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = RGBColor(45, 55, 72) # #2D3748

    # Title
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(2)
    run_title = title_p.add_run("DAILY ENGINEERING WORK PLAN")
    run_title.font.size = Pt(22)
    run_title.font.bold = True
    run_title.font.color.rgb = RGBColor(27, 54, 93) # #1B365D

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_after = Pt(14)
    run_sub = sub_p.add_run("Planned Activities, Expected Deliverables & Dependency Tracking")
    run_sub.font.size = Pt(11)
    run_sub.font.color.rgb = RGBColor(100, 116, 139) # Slate

    # Metadata Table
    meta_table = doc.add_table(rows=3, cols=4)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.autofit = False
    set_table_borders(meta_table, color="CBD5E1")

    col_widths = [Inches(1.3), Inches(2.2), Inches(1.3), Inches(2.2)]
    meta_data = [
        [("Date", True), ("12 November 2026", False), ("Prepared By", True), ("Shreya Upadhyay", False)],
        [("Function", True), ("GCS Software Engineering", False), ("Projects", True), ("Chandipur GCS | Tethered GCS | PDS", False)],
        [("Baseline Lock", True), ("Commit 2c1a1bbbe (Protected)", False), ("Release Target", True), ("Chandipur Field / Tethered v0.1.0-alpha", False)],
    ]

    for row_idx, row in enumerate(meta_table.rows):
        for col_idx, cell in enumerate(row.cells):
            cell.width = col_widths[col_idx]
            text, is_hdr = meta_data[row_idx][col_idx]
            cell.text = text
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(3)
            p.paragraph_format.space_after = Pt(3)
            set_cell_margins(cell, top=60, bottom=60, left=100, right=100)
            if is_hdr:
                set_cell_background(cell, "F1F5F9")
                p.runs[0].font.bold = True
                p.runs[0].font.size = Pt(9.5)
                p.runs[0].font.color.rgb = RGBColor(71, 85, 105)
            else:
                p.runs[0].font.size = Pt(9.5)
                p.runs[0].font.color.rgb = RGBColor(15, 23, 42)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # Executive Summary / Objectives Callout Box
    obj_table = doc.add_table(rows=1, cols=1)
    obj_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = obj_table.rows[0].cells[0]
    cell.width = Inches(7.0)
    set_cell_background(cell, "F8FAFC")
    set_cell_margins(cell, top=120, bottom=120, left=160, right=160)
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = parse_xml(f'<w:tcBorders {nsdecls("w")}><w:left w:val="single" w:sz="24" w:space="0" w:color="1B365D"/><w:top w:val="none"/><w:right w:val="none"/><w:bottom w:val="none"/></w:tcBorders>')
    tcPr.append(tcBorders)

    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(4)
    run_h = p.add_run("Executive Objectives for Today:\n")
    run_h.font.bold = True
    run_h.font.size = Pt(11)
    run_h.font.color.rgb = RGBColor(27, 54, 93)

    bullet_points = [
        "Track 1 (Chandipur GCS): Handover and field-validate IZI-GCS-Chandipur-RC.apk on the Skydroid G30 handheld RC, verifying clean installation, UDP port 5600 wireless video ingestion, and internal MAVLink telemetry.",
        "Track 2 (Tethered GCS): Establish the v0.1.0-alpha.tethered Git release tag on feat/tethered-platform, inject in-app version branding, construct the SafeTTransport Hardware Abstraction Layer (HAL), and issue the Elistair SAFE-T hardware ICD questionnaire.",
        "Track 3 (PDS Platform): Harmonize core platform architecture across P0-P3 priorities and the 10-stage development roadmap, prioritizing PX4 SITL end-to-end mission workflow validation."
    ]
    for pt in bullet_points:
        p_b = cell.add_paragraph()
        p_b.paragraph_format.space_before = Pt(2)
        p_b.paragraph_format.space_after = Pt(2)
        p_b.paragraph_format.left_indent = Inches(0.15)
        run_b = p_b.add_run("•  " + pt)
        run_b.font.size = Pt(9.5)
        run_b.font.color.rgb = RGBColor(51, 65, 85)

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    def add_section_header(title, subtitle=None):
        h = doc.add_paragraph()
        h.paragraph_format.space_before = Pt(14)
        h.paragraph_format.space_after = Pt(2)
        run = h.add_run(title)
        run.font.size = Pt(14)
        run.font.bold = True
        run.font.color.rgb = RGBColor(27, 54, 93)

        if subtitle:
            sub = doc.add_paragraph()
            sub.paragraph_format.space_before = Pt(0)
            sub.paragraph_format.space_after = Pt(6)
            r_sub = sub.add_run(subtitle)
            r_sub.font.size = Pt(9.5)
            r_sub.font.italic = True
            r_sub.font.color.rgb = RGBColor(100, 116, 139)

    def add_subheading(title):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(3)
        r = p.add_run(title)
        r.font.size = Pt(11)
        r.font.bold = True
        r.font.color.rgb = RGBColor(30, 41, 59)

    def add_bullet_list(items):
        for item in items:
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(1.5)
            p.paragraph_format.space_after = Pt(1.5)
            p.paragraph_format.left_indent = Inches(0.2)
            r = p.add_run("▪  " + item)
            r.font.size = Pt(10)
            r.font.color.rgb = RGBColor(51, 65, 85)

    # Section 1: Chandipur GCS
    add_section_header("1. IZI GCS — Chandipur Software Track",
                       "Current Baseline: baseline-chandipur-field-test | Branch: company-ui | Commit: 2c1a1bbbe | Baseline Status: ~95% Ready")

    add_subheading("Planned Tasks for Today:")
    add_bullet_list([
        "Share IZI-GCS-Chandipur-RC.apk (SHA256: f26c09d72e...) with field tester Ankit Lodhi via approved company transfer or direct LAN portal.",
        "Coordinate clean installation on the Skydroid G30 handheld controller; verify that pre-existing test/OEM QGC apps are fully uninstalled first to avoid signature conflicts.",
        "Guide the tester to select the one-click preset 'Skydroid G30 (UDP 5600)' in Camera View / Settings to confirm live wireless video ingestion from the airborne SDR link.",
        "Verify vehicle MAVLink connectivity and telemetry on the G30 using internal UDP port 14550.",
        "Record installation, video-stream, and telemetry test outcomes, capturing system logs and screenshots of any field issues."
    ])

    add_subheading("Expected Deliverables:")
    add_bullet_list([
        "Formal APK handover confirmation and verified artifact build hash.",
        "Skydroid G30 Android 14 installation verification log.",
        "UDP 5600 video and UDP 14550 MAVLink live test records.",
        "Updated field-acceptance checklist categorizing passed, failed, and pending items."
    ])

    add_subheading("Dependencies & Pending Field Acceptance:")
    add_bullet_list([
        "Physical Chandipur drone availability for live flight demonstration and formal acceptance sign-off.",
        "Skydroid G30 physical stick calibration and switch mapping validation under Vehicle Setup.",
        "Long-duration radio telemetry bench soak test to verify zero memory leaks."
    ])

    # Section 2: Tethered GCS
    add_section_header("2. IZI GCS — Tethered Software Track",
                       "Current Baseline: Branch feat/tethered-platform | Target Release: v0.1.0-alpha.tethered | Software/UI: ~80% | Hardware: ~25%")

    add_subheading("Planned Tasks for Today:")
    add_bullet_list([
        "Create the formal annotated Git tag v0.1.0-alpha.tethered on commit 0b06ad4eb on feat/tethered-platform, freezing the verified Step 3 baseline.",
        "Update TetherPlugin.cc and TopBar.qml to display 'IZI GCS - Tethered v0.1.0-alpha' in the application title bar and diagnostics header.",
        "Design and implement the SafeTTransport hardware abstraction interface to cleanly decouple SafeTManager telemetry/state logic from mock generation.",
        "Define dual concrete transport interfaces (Ethernet socket & Serial COM) ready to receive physical drivers once hardware connection specs are finalized.",
        "Prepare the Elistair SAFE-T technical questionnaire covering IP schema, port, baud rate, packet structure, command dictionary, and communication timeout handling.",
        "Build and run automated software boot/smoke tests (--simple-boot-test), documenting simulated performance separately from hardware validation."
    ])

    add_subheading("Expected Deliverables:")
    add_bullet_list([
        "Verified and published Git tag v0.1.0-alpha.tethered.",
        "Updated in-app product and version branding visible in UI and window title.",
        "SafeTTransport HAL interface design, header definitions, and architecture note.",
        "Elistair SAFE-T vendor questionnaire ready for engineering review and submission.",
        "Clean Linux build-tethered test logs and updated hardware dependency register."
    ])

    add_subheading("Dependencies & Pending Hardware Integration:")
    add_bullet_list([
        "Official Elistair SAFE-T Interface Control Document (ICD), Ethernet IP/port or serial pinout specifications.",
        "Physical command packet definitions for winch reel-in/reel-out, tension target, and power cutoff.",
        "Physical tether ground station and drone availability for Hardware-in-the-Loop (HIL) bench testing."
    ])

    # Section 3: PDS Platform
    add_section_header("3. PDS — IZI GCS Platform Strategy & Roadmap",
                       "Objective: Scalable, modular UAV ground station platform ensuring clean reuse across Chandipur, Tethered, and future variants.")

    add_subheading("Planned Tasks for Today:")
    add_bullet_list([
        "Review and categorize the four priority levels of the product roadmap: P0 Core GCS Foundation, P1 Operational Product Capabilities, P2 Advanced UAV Platform, and P3 Productisation & Scalability.",
        "Map current achievements against the 10 development stages (Architecture, Tooling, UAV/MAVLink, Backend/API, Frontend, Mission Planning, Video/Payload, Analytics, Multi-UAV, and Deployment).",
        "Prioritize immediate P0 milestone: End-to-end mission workflow through PX4 SITL, including mission upload/download, execution, progress tracking, and error recovery.",
        "Identify architectural gaps in mission planning, backend services, and vehicle integration; record dependencies and clarification needs.",
        "Ensure auxiliary workstreams (BOM Management, AI Assistant, Ballistics) remain cleanly decoupled from the core GCS flight baseline.",
        "Prepare a phased execution plan outlining upcoming milestones, prerequisites, deliverables, and acceptance criteria."
    ])

    add_subheading("Expected Deliverables:")
    add_bullet_list([
        "Updated P0-P3 platform roadmap and 10-stage development tracker.",
        "Existing-versus-planned capability matrix with rigorous status classifications.",
        "P0 gap list and prioritized SITL mission-workflow action plan.",
        "Milestone-based next-phase execution plan with dependencies and acceptance criteria."
    ])

    # Section 4: Consolidated Summary Table
    add_section_header("4. Priority & Expected Output Summary")

    summary_table = doc.add_table(rows=4, cols=4)
    summary_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    summary_table.autofit = False
    set_table_borders(summary_table, color="CBD5E1")

    s_widths = [Inches(1.5), Inches(2.3), Inches(1.8), Inches(1.4)]
    headers = ["Project Track", "Today's Primary Focus", "Key Expected Output", "Critical Dependency"]
    
    for idx, heading in enumerate(headers):
        cell = summary_table.rows[0].cells[idx]
        cell.width = s_widths[idx]
        cell.text = heading
        set_cell_background(cell, "1B365D")
        set_cell_margins(cell, top=80, bottom=80, left=100, right=100)
        p = cell.paragraphs[0]
        p.runs[0].font.bold = True
        p.runs[0].font.size = Pt(9.5)
        p.runs[0].font.color.rgb = RGBColor(255, 255, 255)

    rows_content = [
        ["Chandipur GCS", "Handheld RC deployment; Skydroid G30 video and MAVLink verification", "Tester handover record, UDP 5600 streaming validation", "Field drone availability & stick calibration"],
        ["Tethered GCS", "Release tag v0.1.0-alpha; UI branding; SafeTTransport HAL; vendor questionnaire", "Alpha baseline tag, HAL driver abstraction, ICD questionnaire", "Elistair SAFE-T protocol documentation"],
        ["PDS Core", "Roadmap harmonization (P0-P3 & 10 stages); prioritize SITL mission workflow", "Updated platform roadmap, P0 gap list, next-phase plan", "Clean separation of non-core auxiliary tools"]
    ]

    for r_idx, r_data in enumerate(rows_content):
        row = summary_table.rows[r_idx + 1]
        bg_col = "F8FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(r_data):
            c = row.cells[c_idx]
            c.width = s_widths[c_idx]
            c.text = val
            set_cell_background(c, bg_col)
            set_cell_margins(c, top=60, bottom=60, left=100, right=100)
            p = c.paragraphs[0]
            p.runs[0].font.size = Pt(9)
            if c_idx == 0:
                p.runs[0].font.bold = True
                p.runs[0].font.color.rgb = RGBColor(27, 54, 93)
            else:
                p.runs[0].font.color.rgb = RGBColor(51, 65, 85)

    # End of Day Sign-off
    add_section_header("5. End-of-Day Review & Sign-Off")
    sign_table = doc.add_table(rows=3, cols=2)
    sign_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(sign_table, color="E2E8F0")

    sign_widths = [Inches(2.5), Inches(4.5)]
    sign_data = [
        ["Tasks Completed at EOD:", ""],
        ["Blockers / Deviations Encountered:", ""],
        ["Priorities for Next Working Session:", ""]
    ]

    for r_idx, (label, val) in enumerate(sign_data):
        row = sign_table.rows[r_idx]
        c0, c1 = row.cells[0], row.cells[1]
        c0.width = sign_widths[0]
        c1.width = sign_widths[1]
        c0.text = label
        c1.text = val
        set_cell_background(c0, "F1F5F9")
        set_cell_margins(c0, top=70, bottom=70, left=100, right=100)
        set_cell_margins(c1, top=70, bottom=70, left=100, right=100)
        c0.paragraphs[0].runs[0].font.bold = True
        c0.paragraphs[0].runs[0].font.size = Pt(9.5)
        c0.paragraphs[0].runs[0].font.color.rgb = RGBColor(71, 85, 105)

    output_path = "/home/izi-system/Shreya/QGCS/qgroundcontrol/DAILY_WORK_PLAN_12_NOV_2026.docx"
    doc.save(output_path)
    print(f"Successfully generated DOCX report at: {output_path}")

    # Copy to build-download for HTTP download
    import shutil
    shutil.copyfile(output_path, "/home/izi-system/Shreya/QGCS/qgroundcontrol/build-download/DAILY_WORK_PLAN_12_NOV_2026.docx")
    print("Copied to build-download folder successfully.")

if __name__ == "__main__":
    build_document()
