import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../overview/overview_controller.dart';
import 'metrics_view.dart';
import 'technology_view.dart';

/// Analiz sekmesi: üstte bölüm seçici (Metrikler | Teknoloji), altında seçili bölüm.
/// İşbirliği sonraki fazda eklenecek.
class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key, required this.controller, required this.api});

  final OverviewController controller;
  final ApiClient api;

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  int _section = 0; // 0: Metrikler, 1: Teknoloji

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Metrikler'), icon: Icon(Icons.timeline)),
                ButtonSegment(value: 1, label: Text('Teknoloji'), icon: Icon(Icons.code)),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(index: _section, children: [
          MetricsView(controller: widget.controller, api: widget.api),
          TechnologyView(controller: widget.controller),
        ]),
      ),
    ]);
  }
}
