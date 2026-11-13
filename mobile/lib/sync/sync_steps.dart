import '../api/sync_api.dart';

enum SyncStepState { waiting, active, done, failed }

/// Senkron ekranındaki bir satır: başlık, durum ve altındaki canlı sayaç metni.
class SyncStep {
  const SyncStep(this.title, this.state, this.detail);
  final String title;
  final SyncStepState state;
  final String? detail;
}

/// Backend'deki gerçek aşamalar, sırasıyla. Ekran bunları uydurmaz, işten okur.
const _phases = ['profile', 'repos', 'commits', 'calendar'];

/// İşin durumundan dört satırlık listeyi üretir (saf fonksiyon: test edilebilir).
List<SyncStep> stepsFor(SyncJob job) {
  // Profil iş açılmadan önce çekilir: bir iş varsa profil her zaman bitmiştir.
  // Bu yüzden "şu anki" aşama en az 1 (repo listesi) sayılır.
  final current = job.phase == 'done' ? _phases.length : _phases.indexOf(job.phase).clamp(1, 3);

  SyncStepState stateOf(int i) {
    if (job.status == 'done' || i < current) return SyncStepState.done;
    if (i > current) return SyncStepState.waiting;
    return job.status == 'failed' ? SyncStepState.failed : SyncStepState.active;
  }

  final total = job.reposTotal;
  final skipped = job.reposSkipped > 0 ? ' · ${job.reposSkipped} değişmemiş' : '';
  return [
    SyncStep('Profil', stateOf(0), 'GitHub hesabın doğrulandı'),
    SyncStep('Repo listesi', stateOf(1),
        total == null ? 'Repolar listeleniyor…' : '$total repo bulundu'),
    SyncStep('Commit geçmişi', stateOf(2),
        total == null ? null : '${job.reposDone} / $total repo · ${job.commitsSynced} commit$skipped'),
    SyncStep('Katkı takvimi', stateOf(3), switch (stateOf(3)) {
      SyncStepState.done => '${job.calendarDays} gün',
      SyncStepState.active => 'GitHub takvimi alınıyor…',
      _ => null,
    }),
  ];
}

/// "%42" biçiminde yüzde; ilerleme henüz bilinmiyorsa null.
String? percentText(double? progress) =>
    progress == null ? null : '%${(progress * 100).round()}';

// --- Gösterim hızı ---------------------------------------------------------------------
// Demo senkronu bir saniyeden kısa sürer; ekran göz açıp kapayana kadar geçmesin diye
// aşamalar birer birer "bitti"ye çevrilir. Sayılar değişmez, yalnız gösterim sırası/hızı.

/// Baştan kaç aşama bitmiş (gerçekte)?
int doneCount(List<SyncStep> steps) =>
    steps.takeWhile((s) => s.state == SyncStepState.done).length;

/// Gerçek aşamaları, en fazla [shown] tanesi "bitti" görünecek şekilde gösterir.
/// Sıradaki aşama "sürüyor" (gerçekte hata verdiyse "hata"), sonrakiler "bekliyor".
List<SyncStep> pacedSteps(List<SyncStep> real, int shown) => [
      for (var i = 0; i < real.length; i++)
        if (i < shown)
          real[i]
        else if (i == shown && real[i].state != SyncStepState.waiting)
          SyncStep(
            real[i].title,
            real[i].state == SyncStepState.failed ? SyncStepState.failed : SyncStepState.active,
            real[i].detail,
          )
        else
          SyncStep(real[i].title, SyncStepState.waiting, null),
    ];

/// Takvimi soldan sağa [fraction] (0-1) kadar gösterir; kalan günler boş (0) çizilir.
List<(DateTime, int)> revealDays(List<(DateTime, int)> days, double fraction) {
  final visible = (days.length * fraction.clamp(0.0, 1.0)).ceil();
  return [for (var i = 0; i < days.length; i++) (days[i].$1, i < visible ? days[i].$2 : 0)];
}
