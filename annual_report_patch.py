# This patches annual_report.py to add hours and depreciation sections

f = open(r'C:\Users\flori\bigdogg-backend\app\routers\annual_report.py', 'r', encoding='utf-8')
content = f.read()
f.close()

# Find where get_year_data returns and add hours + depreciation data
old_return = '''    total_rev = round(sum(q["revenue_ex_btw"] for q in quarters), 2)
    total_exp = round(sum(q["expenses_ex_btw"] for q in quarters), 2)
    total_btw = round(sum(q["btw_to_pay"] for q in quarters), 2)
    net_profit = round(total_rev - total_exp, 2)

    return {
        "quarters": quarters,
        "total_revenue_ex_btw": total_rev,
        "total_expenses_ex_btw": total_exp,
        "total_btw_to_pay": total_btw,
        "net_profit_indicative": net_profit,
    }'''

new_return = '''    total_rev = round(sum(q["revenue_ex_btw"] for q in quarters), 2)
    total_exp = round(sum(q["expenses_ex_btw"] for q in quarters), 2)
    total_btw = round(sum(q["btw_to_pay"] for q in quarters), 2)
    net_profit = round(total_rev - total_exp, 2)

    # Hours: manual + invoice-derived
    manual_hrs_result = supabase.table("hours").select("hours")\
        .eq("user_id", user_id)\
        .gte("date", f"{year}-01-01")\
        .lte("date", f"{year}-12-31")\
        .execute()
    manual_hours = round(sum(float(h["hours"]) for h in (manual_hrs_result.data or [])), 2)

    inv_result = supabase.table("invoices").select("id, status")\
        .eq("user_id", user_id).neq("status", "draft")\
        .gte("invoice_date", f"{year}-01-01")\
        .lte("invoice_date", f"{year}-12-31").execute()
    inv_ids = [i["id"] for i in (inv_result.data or [])]
    invoice_hours = 0.0
    if inv_ids:
        lines = supabase.table("invoice_lines").select("quantity, unit")\
            .in_("invoice_id", inv_ids).execute()
        for line in (lines.data or []):
            unit = (line.get("unit") or "fixed").lower()
            qty = float(line.get("quantity", 0) or 0)
            if unit == "day":
                invoice_hours += qty * 9.0
            elif unit == "hour":
                invoice_hours += qty
    invoice_hours = round(invoice_hours, 2)
    total_hours = round(manual_hours + invoice_hours, 2)

    # Depreciation
    investments = supabase.table("investments").select("*")\
        .eq("user_id", user_id).execute()
    total_depreciation = 0.0
    depreciation_items = []
    for inv in (investments.data or []):
        dep_years = inv.get("depreciation_years", 5) or 5
        purchase_year = int((inv.get("purchase_date") or f"{year}-01-01")[:4])
        if purchase_year <= year < purchase_year + dep_years:
            annual_dep = round(float(inv.get("amount", 0)) / dep_years, 2)
            total_depreciation += annual_dep
            depreciation_items.append({
                "description": inv.get("description", ""),
                "amount": annual_dep,
                "purchase_date": inv.get("purchase_date", ""),
            })
    total_depreciation = round(total_depreciation, 2)

    return {
        "quarters": quarters,
        "total_revenue_ex_btw": total_rev,
        "total_expenses_ex_btw": total_exp,
        "total_btw_to_pay": total_btw,
        "net_profit_indicative": net_profit,
        "total_hours": total_hours,
        "manual_hours": manual_hours,
        "invoice_hours": invoice_hours,
        "total_depreciation": total_depreciation,
        "depreciation_items": depreciation_items,
    }'''

content = content.replace(old_return, new_return)
print('Step 1 (data):', 'total_hours' in content)

# Now find where the PDF is built and add hours + depreciation sections
# Find the AI tips section and insert before it
old_pdf_section = '''    # ── AI Tips ──────────────────────────────────────────────────────────────'''

new_pdf_insert = '''    # ── Hours Summary ─────────────────────────────────────────────────────────
    story.append(Spacer(1, 6*mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.HexColor(MID_GREY)))
    story.append(Spacer(1, 4*mm))

    hours_title_style = ParagraphStyle('HoursTitle', fontSize=13, fontName='Helvetica-Bold',
        textColor=colors.HexColor(TEAL), spaceAfter=6)
    story.append(Paragraph(lang.get("hours_title", "Hours Overview"), hours_title_style))

    total_hours = data.get("total_hours", 0)
    manual_hours = data.get("manual_hours", 0)
    invoice_hours = data.get("invoice_hours", 0)
    urencriterium = 1225
    pct = min(round(total_hours / urencriterium * 100, 1), 100)

    hours_data = [
        [lang.get("manual_hours", "Manual hours"), f"{manual_hours:.1f} u"],
        [lang.get("invoice_hours", "From invoices"), f"{invoice_hours:.1f} u"],
        [lang.get("total_hours", "Total hours"), f"{total_hours:.1f} u"],
        [lang.get("urencriterium", "Urencriterium (1,225 u)"), f"{pct}%"],
    ]
    hours_table = Table(hours_data, colWidths=[page_width * 0.65, page_width * 0.35])
    hours_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -2), 'Helvetica'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 10),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor(TEXT_SECONDARY)),
        ('TEXTCOLOR', (1, 0), (1, -1), colors.HexColor(TEAL)),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('ROWBACKGROUNDS', (0, 0), (-1, -1), [colors.white, colors.HexColor(LIGHT_GREY)]),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('LINEBELOW', (0, -2), (-1, -2), 0.5, colors.HexColor(MID_GREY)),
    ]))
    story.append(hours_table)

    # ── Depreciation Summary ───────────────────────────────────────────────────
    total_dep = data.get("total_depreciation", 0)
    dep_items = data.get("depreciation_items", [])
    if total_dep > 0:
        story.append(Spacer(1, 6*mm))
        dep_title_style = ParagraphStyle('DepTitle', fontSize=13, fontName='Helvetica-Bold',
            textColor=colors.HexColor(TEAL), spaceAfter=6)
        story.append(Paragraph(lang.get("depreciation_title", "Depreciation"), dep_title_style))

        dep_data = [[lang.get("investment", "Investment"),
                     lang.get("purchase_date", "Purchase date"),
                     lang.get("annual_dep", "Annual depreciation")]]
        for item in dep_items:
            dep_data.append([item["description"], item["purchase_date"],
                              f'\u20ac{item["amount"]:.2f}'])
        dep_data.append([lang.get("total_dep", "Total depreciation"), "",
                         f'\u20ac{total_dep:.2f}'])

        dep_table = Table(dep_data, colWidths=[page_width * 0.45, page_width * 0.25, page_width * 0.30])
        dep_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor(TEAL)),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
            ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, colors.HexColor(LIGHT_GREY)]),
            ('LINEBELOW', (0, -2), (-1, -2), 0.5, colors.HexColor(MID_GREY)),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
        ]))
        story.append(dep_table)

    # ── AI Tips ──────────────────────────────────────────────────────────────'''

content = content.replace(old_pdf_section, new_pdf_insert)
print('Step 2 (PDF sections):', 'Hours Overview' in content)

# Add language strings for hours/depreciation
old_lang_nl = '''    lang = {
        "title": f"Jaarrapport {year}",'''

new_lang_nl = '''    lang = {
        "title": f"Jaarrapport {year}",
        "hours_title": "Urenregistratie",
        "manual_hours": "Handmatige uren",
        "invoice_hours": "Uren via facturen",
        "total_hours": "Totaal uren",
        "urencriterium": "Urencriterium (1.225 u)",
        "depreciation_title": "Afschrijvingen",
        "investment": "Investering",
        "purchase_date": "Aankoopdatum",
        "annual_dep": "Jaarlijkse afschrijving",
        "total_dep": "Totaal afschrijving",'''

content = content.replace(old_lang_nl, new_lang_nl, 1)

old_lang_en = '''    lang = {
        "title": f"Annual Report {year}",'''

new_lang_en = '''    lang = {
        "title": f"Annual Report {year}",
        "hours_title": "Hours Overview",
        "manual_hours": "Manual hours",
        "invoice_hours": "Hours from invoices",
        "total_hours": "Total hours",
        "urencriterium": "Hour criterion (1,225 hrs)",
        "depreciation_title": "Depreciation",
        "investment": "Investment",
        "purchase_date": "Purchase date",
        "annual_dep": "Annual depreciation",
        "total_dep": "Total depreciation",'''

content = content.replace(old_lang_en, new_lang_en, 1)
print('Step 3 (language strings):', 'hours_title' in content)

f = open(r'C:\Users\flori\bigdogg-backend\app\routers\annual_report.py', 'w', encoding='utf-8')
f.write(content)
f.close()
print('Done')
