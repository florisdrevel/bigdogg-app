f = open(r'C:\Users\flori\bigdogg_app\lib\screens\overview_screen.dart', 'r', encoding='utf-8')
content = f.read()
f.close()

# 1. Add manualYear, invoiceYear, invEntries variables
old1 = "    final totalYear = (_hoursData?['total_year'] as num? ?? 0).toDouble();\n    final totalQuarter = (_hoursData?['total_quarter'] as num? ?? 0).toDouble();\n    final progress = (_hoursData?['urencriterium_progress'] as num? ?? 0).toDouble();\n    final target = 1225;\n    final entries = (_hoursData?['entries'] as List? ?? []).take(5).toList();"

new1 = "    final totalYear = (_hoursData?['total_year'] as num? ?? 0).toDouble();\n    final totalQuarter = (_hoursData?['total_quarter'] as num? ?? 0).toDouble();\n    final progress = (_hoursData?['urencriterium_progress'] as num? ?? 0).toDouble();\n    final manualYear = (_hoursData?['manual_year'] as num? ?? 0).toDouble();\n    final invoiceYear = (_hoursData?['invoice_year'] as num? ?? 0).toDouble();\n    final target = 1225;\n    final entries = (_hoursData?['entries'] as List? ?? []).take(5).toList();\n    final invEntries = (_hoursData?['invoice_hours_breakdown'] as List? ?? []).take(5).toList();"

content = content.replace(old1, new1)
print('Step 1:', 'manualYear' in content)

# 2. Add source breakdown row before progress bar
old2 = "                const SizedBox(height: 12),\n\n                // Progress bar"
new2 = """                const SizedBox(height: 8),
                if (invoiceYear > 0 || manualYear > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BigDoggTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BigDoggTheme.lightBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 12, color: BigDoggTheme.lightTextSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${isNl ? "Handmatig" : "Manual"}: ${manualYear.toStringAsFixed(1)}u  \u00b7  ${isNl ? "Facturen" : "Invoices"}: ${invoiceYear.toStringAsFixed(1)}u',
                        style: const TextStyle(fontSize: 11, color: BigDoggTheme.lightTextSecondary),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),

                // Progress bar"""

content = content.replace(old2, new2)
print('Step 2:', 'invoiceYear > 0' in content)

# 3. Replace manual entries section with combined manual + invoice entries
old3 = """                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(isNl ? 'Recente registraties' : 'Recent entries',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextSecondary)),
                  const SizedBox(height: 6),
                  ...entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(e['date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          e['description']?.toString().isNotEmpty == true ? e['description'] : (isNl ? 'Geen omschrijving' : 'No description'),
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Text('${(e['hours'] as num).toStringAsFixed(1)} u',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _deleteHoursEntry(e['id']),
                          child: const Icon(Icons.close, size: 14, color: BigDoggTheme.lightTextHint),
                        ),
                      ],
                    ),
                  )).toList(),
                ],"""

new3 = """                if (entries.isNotEmpty || invEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  if (entries.isNotEmpty) ...[
                    Text(isNl ? 'Handmatige registraties' : 'Manual entries',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextSecondary)),
                    const SizedBox(height: 6),
                    ...entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Text(e['date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          e['description']?.toString().isNotEmpty == true ? e['description'] : (isNl ? 'Geen omschrijving' : 'No description'),
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Text('${(e['hours'] as num).toStringAsFixed(1)} u',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _deleteHoursEntry(e['id']),
                          child: const Icon(Icons.close, size: 14, color: BigDoggTheme.lightTextHint),
                        ),
                      ]),
                    )).toList(),
                  ],
                  if (invEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(isNl ? 'Vanuit facturen' : 'From invoices',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.lightTextSecondary)),
                    const SizedBox(height: 6),
                    ...invEntries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Text(e['date'] ?? '', style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextHint)),
                        const SizedBox(width: 8),
                        const Icon(Icons.receipt_long_outlined, size: 11, color: BigDoggTheme.teal700),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          '${e["invoice_number"] ?? ""} \u00b7 ${e["description"] ?? ""}',
                          style: const TextStyle(fontSize: 12, color: BigDoggTheme.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Text('${(e['hours'] as num).toStringAsFixed(1)} u',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BigDoggTheme.teal800)),
                      ]),
                    )).toList(),
                  ],
                ],"""

content = content.replace(old3, new3)
print('Step 3:', 'invEntries.isNotEmpty' in content)

f = open(r'C:\Users\flori\bigdogg_app\lib\screens\overview_screen.dart', 'w', encoding='utf-8')
f.write(content)
f.close()
print('All done')
