import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../overview/overview_controller.dart';
import 'collaboration_view.dart';
import 'metrics_view.dart';
import 'technology_view.dart';

/// Analiz sekmesi: üstte bölüm seçici (Metrikler | Teknoloji | İşbirliği), altında seçili bölüm.
class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key, required this.controller, required this.api});

  final OverviewController controller;
  final ApiClient api;

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  int _section = 0; // 0: Metrikler, 1: Teknoloji, 2: İşbirliği

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
              // İkon yok: dar telefonda üç etiket tek satıra sığsın (360 px'te "Teknoloji" bölünüyordu).
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Metrikler')),
                ButtonSegment(value: 1, label: Text('Teknoloji')),
                ButtonSegment(value: 2, label: Text('İşbirliği')),
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
          CollaborationView(controller: widget.controller),
        ]),
      ),
    ]);
  }
}
