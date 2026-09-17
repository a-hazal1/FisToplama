import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

const _boxName = 'receipts';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(_boxName);
  runApp(const FisToplamaApp());
}

class FisToplamaApp extends StatelessWidget {
  const FisToplamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB42318),
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFC),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fiş Toplama',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE6E9EE)),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE2E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE2E8)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class Receipt {
  final String id;
  final String branch;
  final String note;
  final DateTime createdAt;
  final Uint8List imageBytes;

  Receipt({
    required this.id,
    required this.branch,
    required this.note,
    required this.createdAt,
    required this.imageBytes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch': branch,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'image': base64Encode(imageBytes),
      };

  factory Receipt.fromMap(Map map) => Receipt(
        id: map['id'] as String,
        branch: (map['branch'] ?? '') as String,
        note: (map['note'] ?? '') as String,
        createdAt: DateTime.parse(map['createdAt'] as String),
        imageBytes: base64Decode(map['image'] as String),
      );
}

class ReceiptRepository {
  final Box box = Hive.box(_boxName);

  List<Receipt> all() {
    final items = box.values
        .map((e) => Receipt.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> add(Receipt receipt) => box.put(receipt.id, receipt.toMap());
  Future<void> delete(String id) => box.delete(id);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final selected = <String>{};
  final repo = ReceiptRepository();

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final pages = [
      DashboardPage(
        repo: repo,
        selected: selected,
        onChanged: refresh,
        goToArchive: () => setState(() => index = 1),
        goToAdd: () => setState(() => index = 2),
      ),
      ArchivePage(repo: repo, selected: selected, onChanged: refresh),
      AddReceiptPage(
        repo: repo,
        onSaved: () {
          refresh();
          setState(() => index = 1);
        },
      ),
      PdfPage(repo: repo, selected: selected, onChanged: refresh),
    ];

    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          title: const BrandTitle(),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          scrolledUnderElevation: 1,
        ),
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Panel'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Fişler'),
            NavigationDestination(icon: Icon(Icons.add_a_photo_outlined), selectedIcon: Icon(Icons.add_a_photo), label: 'Ekle'),
            NavigationDestination(icon: Icon(Icons.picture_as_pdf_outlined), selectedIcon: Icon(Icons.picture_as_pdf), label: 'PDF'),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFF111827),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 20, 22, 26),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandTitle(dark: true),
                    ),
                  ),
                  _RailItem(icon: Icons.dashboard_rounded, label: 'Genel Bakış', selected: index == 0, onTap: () => setState(() => index = 0)),
                  _RailItem(icon: Icons.receipt_long_rounded, label: 'Fiş Arşivi', selected: index == 1, onTap: () => setState(() => index = 1)),
                  _RailItem(icon: Icons.add_a_photo_rounded, label: 'Yeni Fiş', selected: index == 2, onTap: () => setState(() => index = 2)),
                  _RailItem(icon: Icons.picture_as_pdf_rounded, label: '6’lı A4 PDF', selected: index == 3, onTap: () => setState(() => index = 3)),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(.08)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.white70),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Fişler bu sürümde cihazda saklanır.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
                  ),
                  child: Row(
                    children: [
                      const Text('Fiş Yönetim Sistemi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      _TopBadge(icon: Icons.check_circle_outline, text: '${selected.length} fiş seçili'),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => setState(() => index = 2),
                        icon: const Icon(Icons.add),
                        label: const Text('Yeni Fiş'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: pages[index]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  final bool dark;
  const BrandTitle({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFB42318),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FişToplama',
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              'Dijital fiş arşivi',
              style: TextStyle(
                color: dark ? Colors.white54 : const Color(0xFF7A8494),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: selected ? Colors.white.withOpacity(.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: selected ? Colors.white : Colors.white60, size: 21),
                const SizedBox(width: 13),
                Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TopBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E8ED)),
      ),
      child: Row(children: [Icon(icon, size: 17, color: const Color(0xFF667085)), const SizedBox(width: 7), Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
    );
  }
}

class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: child,
        ),
      );
}

class DashboardPage extends StatelessWidget {
  final ReceiptRepository repo;
  final Set<String> selected;
  final VoidCallback onChanged;
  final VoidCallback goToArchive;
  final VoidCallback goToAdd;

  const DashboardPage({super.key, required this.repo, required this.selected, required this.onChanged, required this.goToArchive, required this.goToAdd});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: repo.box.listenable(),
      builder: (_, Box box, __) {
        final receipts = repo.all();
        final today = receipts.where((r) {
          final now = DateTime.now();
          return r.createdAt.year == now.year && r.createdAt.month == now.month && r.createdAt.day == now.day;
        }).length;
        final pages = (selected.length / 6).ceil();

        return PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Genel Bakış', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Fişleri tek yerde topla, seç ve 6’lı A4 PDF oluştur.', style: TextStyle(color: Color(0xFF667085))),
              const SizedBox(height: 22),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 540 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: cols == 1 ? 3.2 : 2.0,
                  children: [
                    StatCard(title: 'Toplam Fiş', value: '${receipts.length}', icon: Icons.receipt_long, subtitle: 'Arşivde kayıtlı'),
                    StatCard(title: 'Bugün Eklenen', value: '$today', icon: Icons.today, subtitle: 'Bugünkü kayıtlar'),
                    StatCard(title: 'Seçili Fiş', value: '${selected.length}', icon: Icons.task_alt, subtitle: 'PDF için seçilen'),
                    StatCard(title: 'A4 Sayfası', value: '$pages', icon: Icons.description_outlined, subtitle: '6 fiş / sayfa'),
                  ],
                );
              }),
              const SizedBox(height: 22),
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 850) {
                  return Column(
                    children: [
                      QuickCard(onAdd: goToAdd, onArchive: goToArchive),
                      const SizedBox(height: 16),
                      RecentCard(receipts: receipts.take(5).toList()),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: QuickCard(onAdd: goToAdd, onArchive: goToArchive)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: RecentCard(receipts: receipts.take(5).toList())),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.subtitle});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: const Color(0xFFB42318)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF667085), fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class QuickCard extends StatelessWidget {
  final VoidCallback onAdd, onArchive;
  const QuickCard({super.key, required this.onAdd, required this.onArchive});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hızlı İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('En sık kullanılan işlemlere hızlıca ulaş.', style: TextStyle(color: Color(0xFF667085), fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_a_photo), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Yeni Fiş Ekle')))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onArchive, icon: const Icon(Icons.receipt_long), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Fiş Arşivine Git')))),
            ],
          ),
        ),
      );
}

class RecentCard extends StatelessWidget {
  final List<Receipt> receipts;
  const RecentCard({super.key, required this.receipts});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Son Eklenen Fişler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (receipts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('Henüz fiş eklenmedi.', style: TextStyle(color: Color(0xFF98A2B3)))),
                )
              else
                ...receipts.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(r.imageBytes, width: 48, height: 48, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.branch.isEmpty ? 'Şube belirtilmedi' : r.branch, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt), style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      );
}

class ArchivePage extends StatefulWidget {
  final ReceiptRepository repo;
  final Set<String> selected;
  final VoidCallback onChanged;
  const ArchivePage({super.key, required this.repo, required this.selected, required this.onChanged});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.repo.box.listenable(),
      builder: (_, Box box, __) {
        final q = search.text.trim().toLowerCase();
        final receipts = widget.repo.all().where((r) => q.isEmpty || r.branch.toLowerCase().contains(q) || r.note.toLowerCase().contains(q)).toList();

        return PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 12,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fiş Arşivi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('PDF’e girecek fişleri kartlara dokunarak seç.', style: TextStyle(color: Color(0xFF667085))),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: receipts.isEmpty ? null : () {
                          for (final r in receipts) widget.selected.add(r.id);
                          widget.onChanged();
                          setState(() {});
                        },
                        icon: const Icon(Icons.done_all),
                        label: const Text('Tümünü Seç'),
                      ),
                      TextButton(
                        onPressed: widget.selected.isEmpty ? null : () {
                          widget.selected.clear();
                          widget.onChanged();
                          setState(() {});
                        },
                        child: const Text('Seçimi Temizle'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Şube veya açıklama ara...'),
              ),
              const SizedBox(height: 18),
              if (receipts.isEmpty)
                const EmptyCard()
              else
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 1100 ? 4 : c.maxWidth > 760 ? 3 : c.maxWidth > 480 ? 2 : 1;
                  return GridView.builder(
                    itemCount: receipts.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: cols == 1 ? 1.2 : .78,
                    ),
                    itemBuilder: (_, i) {
                      final r = receipts[i];
                      final isSelected = widget.selected.contains(r.id);
                      return ReceiptCard(
                        receipt: r,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            isSelected ? widget.selected.remove(r.id) : widget.selected.add(r.id);
                          });
                          widget.onChanged();
                        },
                        onDelete: () async {
                          await widget.repo.delete(r.id);
                          widget.selected.remove(r.id);
                          widget.onChanged();
                        },
                      );
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const ReceiptCard({super.key, required this.receipt, required this.selected, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: selected ? const Color(0xFFB42318) : const Color(0xFFE6E9EE), width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFFF2F4F7), child: Image.memory(receipt.imageBytes, fit: BoxFit.contain)),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFB42318) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? const Color(0xFFB42318) : const Color(0xFFD0D5DD)),
                          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
                        ),
                        child: Icon(selected ? Icons.check : Icons.add, size: 18, color: selected ? Colors.white : const Color(0xFF667085)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(receipt.branch.isEmpty ? 'Şube belirtilmedi' : receipt.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(DateFormat('dd.MM.yyyy • HH:mm').format(receipt.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3))),
                        if (receipt.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(receipt.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                        ]
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fişi sil?'),
        content: const Text('Bu fiş cihazdaki arşivden kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (yes == true) onDelete();
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.receipt_long_outlined, size: 34, color: Color(0xFF98A2B3)),
              ),
              const SizedBox(height: 15),
              const Text('Henüz fiş yok', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 5),
              const Text('Yeni fiş eklediğinde burada görünecek.', style: TextStyle(color: Color(0xFF98A2B3))),
            ],
          ),
        ),
      );
}

class AddReceiptPage extends StatefulWidget {
  final ReceiptRepository repo;
  final VoidCallback onSaved;
  const AddReceiptPage({super.key, required this.repo, required this.onSaved});

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final branch = TextEditingController();
  final note = TextEditingController();
  final picker = ImagePicker();
  Uint8List? image;
  bool saving = false;

  Future<void> choose(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => image = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf açılamadı: $e')));
    }
  }

  Future<void> save() async {
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce fiş fotoğrafı ekle.')));
      return;
    }
    setState(() => saving = true);
    final r = Receipt(
      id: const Uuid().v4(),
      branch: branch.text.trim(),
      note: note.text.trim(),
      createdAt: DateTime.now(),
      imageBytes: image!,
    );
    await widget.repo.add(r);
    if (!mounted) return;
    setState(() => saving = false);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiş arşive kaydedildi.')));
  }

  @override
  Widget build(BuildContext context) {
    final canCamera = !kIsWeb;

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Yeni Fiş Ekle', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Fotoğrafı ekle; istersen şube ve kısa açıklama yaz.', style: TextStyle(color: Color(0xFF667085))),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 820;
            final preview = Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Fiş Görseli', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 14),
                    AspectRatio(
                      aspectRatio: .83,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE1E5EA)),
                        ),
                        child: image == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.document_scanner_outlined, size: 52, color: Color(0xFF98A2B3)),
                                  SizedBox(height: 12),
                                  Text('Fiş önizlemesi', style: TextStyle(fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text('Fotoğraf eklediğinde burada görünür.', style: TextStyle(color: Color(0xFF98A2B3), fontSize: 12)),
                                ],
                              )
                            : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(image!, fit: BoxFit.contain)),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final form = Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Fiş Bilgileri', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 18),
                    TextField(controller: branch, decoration: const InputDecoration(labelText: 'Mağaza / Şube', hintText: 'Örn. Üsküdar')),
                    const SizedBox(height: 12),
                    TextField(controller: note, minLines: 3, maxLines: 4, decoration: const InputDecoration(labelText: 'Açıklama', hintText: 'İsteğe bağlı not')),
                    const SizedBox(height: 18),
                    if (canCamera) ...[
                      FilledButton.icon(
                        onPressed: () => choose(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Kamerayla Fiş Çek')),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => choose(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(kIsWeb ? 'Bilgisayardan Görsel Seç' : 'Galeriden Görsel Seç')),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Fişi Arşive Kaydet')),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Not: Web sürümünde dosya seçimi kullanılır. Telefonda native sürüm kamera ile doğrudan çekim yapar.',
                      style: TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
                    ),
                  ],
                ),
              ),
            );

            if (!wide) {
              return Column(children: [preview, const SizedBox(height: 16), form]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: preview), const SizedBox(width: 16), Expanded(child: form)]);
          }),
        ],
      ),
    );
  }
}

class PdfPage extends StatelessWidget {
  final ReceiptRepository repo;
  final Set<String> selected;
  final VoidCallback onChanged;
  const PdfPage({super.key, required this.repo, required this.selected, required this.onChanged});

  Future<Uint8List> buildPdf(List<Receipt> receipts) async {
    final doc = pw.Document();

    for (var start = 0; start < receipts.length; start += 6) {
      final chunk = receipts.sublist(start, (start + 6).clamp(0, receipts.length));
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (_) {
            final rows = <pw.TableRow>[];
            for (var row = 0; row < 3; row++) {
              final cells = <pw.Widget>[];
              for (var col = 0; col < 2; col++) {
                final index = row * 2 + col;
                if (index < chunk.length) {
                  final r = chunk[index];
                  final img = pw.MemoryImage(r.imageBytes);
                  cells.add(
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: .7)),
                      child: pw.Column(
                        children: [
                          pw.Expanded(child: pw.Image(img, fit: pw.BoxFit.contain)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            [r.branch, r.note].where((e) => e.trim().isNotEmpty).join(' • '),
                            maxLines: 1,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  cells.add(pw.SizedBox());
                }
              }
              rows.add(pw.TableRow(children: cells));
            }

            return pw.Table(
              border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.white, width: 6)),
              children: rows,
              columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
            );
          },
        ),
      );
    }
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: repo.box.listenable(),
      builder: (_, Box box, __) {
        final all = repo.all();
        final receipts = all.where((r) => selected.contains(r.id)).toList();
        final pageCount = (receipts.length / 6).ceil();

        return PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('6’lı A4 PDF', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Her A4 sayfasına 2 sütun × 3 satır olacak şekilde 6 fiş yerleşir.', style: TextStyle(color: Color(0xFF667085))),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: LayoutBuilder(builder: (context, c) {
                    final compact = c.maxWidth < 650;
                    final stats = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniStat(label: 'Seçili', value: '${receipts.length}'),
                        const SizedBox(width: 12),
                        _MiniStat(label: 'Sayfa', value: '$pageCount'),
                      ],
                    );
                    final buttons = Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        OutlinedButton.icon(
                          onPressed: receipts.isEmpty ? null : () async {
                            await Printing.layoutPdf(onLayout: (_) => buildPdf(receipts));
                          },
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Yazdır / Önizle'),
                        ),
                        FilledButton.icon(
                          onPressed: receipts.isEmpty ? null : () async {
                            final bytes = await buildPdf(receipts);
                            await Printing.sharePdf(bytes: bytes, filename: 'fisler_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
                          },
                          icon: const Icon(Icons.ios_share),
                          label: const Text('PDF Paylaş / Kaydet'),
                        ),
                      ],
                    );

                    return compact
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [stats, const SizedBox(height: 16), buttons])
                        : Row(children: [stats, const Spacer(), buttons]);
                  }),
                ),
              ),
              const SizedBox(height: 16),
              if (receipts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 48, color: Color(0xFF98A2B3)),
                          const SizedBox(height: 12),
                          const Text('PDF için fiş seçilmedi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('Fiş Arşivi ekranından PDF’e girecek fişleri seç.', style: TextStyle(color: Color(0xFF98A2B3))),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: all.isEmpty ? null : () {
                              for (final r in all) selected.add(r.id);
                              onChanged();
                            },
                            child: const Text('Tüm fişleri seç'),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                const Text('Seçilen Fişler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: receipts.map((r) => Container(
                    width: 118,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE3E6EB))),
                    child: Column(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(r.imageBytes, width: 104, height: 126, fit: BoxFit.contain)),
                      const SizedBox(height: 6),
                      Text(r.branch.isEmpty ? 'Fiş' : r.branch, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ]),
                  )).toList(),
                )
              ]
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3), fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
        ]),
      );
}
