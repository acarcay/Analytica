// lib/models/quiz.dart

class QuizQuestion {
  final String id;
  final String section;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.section,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map, String id) {
    final options = (map['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return QuizQuestion(
      id: id,
      section: map['section']?.toString() ?? '',
      question: map['question']?.toString() ?? '',
      options: options,
      correctIndex: (map['correctIndex'] is int) ? map['correctIndex'] as int : int.tryParse(map['correctIndex']?.toString() ?? '') ?? 0,
      explanation: map['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }
}

final sampleQuizQuestions = <QuizQuestion>[
  QuizQuestion(
    id: 'q1',
    section: 'Bölüm 1: Temel Siyaset Bilimi Kavramları',
    question: 'Bir ülkede hükümetin bir yasa çıkardığını, ancak daha sonra Anayasa Mahkemesi\'nin bu yasayı "Anayasa\'ya aykırı" diyerek iptal etmesini en net örneği hangi ilkeye gösterir?',
    options: ['Yasama dokunulmazlığı', 'Güçler ayrılığı', 'Milli egemenlik', 'Sosyal devlet'],
    correctIndex: 1,
    explanation: 'Güçler ayrılığı: Mahkemenin Meclis\'in çıkardığı bir yasayı iptal etmesi bu denetimin klasik örneğidir.',
  ),
  QuizQuestion(
    id: 'q2',
    section: 'Bölüm 1: Temel Siyaset Bilimi Kavramları',
    question: 'Siyasi tartışmalarda, genellikle "sol" siyasetle ilişkilendirilen temel öncelik aşağıdakilerden hangisidir?',
    options: ['Bireysel özgürlüklerin önceliği ve serbest piyasa', 'Toplumsal eşitlik ve devletin ekonomiye müdahalesi', 'Geleneksel değerlerin ve kurumların korunması', 'Bürokrasinin azaltılması ve vergilerin düşürülmesi'],
    correctIndex: 1,
    explanation: 'Geleneksel olarak sol siyaset, gelir dağılımında adaleti sağlamak ve devletin sosyal-ekonomik hayata müdahalesini savunur.',
  ),
  QuizQuestion(
    id: 'q3',
    section: 'Bölüm 2: Türkiye\'nin Siyasi Yapısı',
    question: 'Türkiye\'de kanun tekliflerinin görüşüldüğü ve oylanarak kanunlaştığı kurum hangisidir?',
    options: ['Anayasa Mahkemesi', 'Cumhurbaşkanlığı Külliyesi', 'Yargıtay', 'Türkiye Büyük Millet Meclisi (TBMM)'],
    correctIndex: 3,
    explanation: 'Anayasa\'ya göre yasa yapma yetkisi TBMM\'ye aittir.',
  ),
  QuizQuestion(
    id: 'q4',
    section: 'Bölüm 2: Türkiye\'nin Siyasi Yapısı',
    question: 'Normal şartlar altında Cumhurbaşkanlığı ve Milletvekilliği seçimleri kaç yılda birdir?',
    options: ['4 yılda bir', '5 yılda bir', '6 yılda bir', 'Hükümet istediği zaman'],
    correctIndex: 1,
    explanation: '2017 değişikliği ile hem Cumhurbaşkanlığı hem de Milletvekilliği seçimleri 5 yılda bir yapılır.',
  ),
  QuizQuestion(
    id: 'q5',
    section: 'Bölüm 3: Söylem Analizi ve Güncel Olaylar',
    question: 'Bir siyasetçinin "elitler sizi anlamaz, gerçek irade halktır" tarzı hitabeti en belirgin hangi kavrama işaret eder?',
    options: ['Diplomasi', 'Popülizm', 'Liberalizm', 'Pragmatizm'],
    correctIndex: 1,
    explanation: 'Popülizm, halk ve elitleri karşıtlaştıran bir siyasi söylem tarzıdır.',
  ),
  QuizQuestion(
    id: 'q6',
    section: 'Bölüm 3: Söylem Analizi ve Güncel Olaylar',
    question: 'Merkez Bankası\'nın faizleri artırmasının temel amacı genellikle hangisidir?',
    options: ['Tüketimi artırmak', 'Enflasyonu kontrol altına almak ve TL\'yi değerli kılmak', 'İhracatı artırmak', 'İşsizliği azaltmak'],
    correctIndex: 1,
    explanation: 'Faiz artırımı enflasyonu düşürmeye ve yerel para birimini güçlendirmeye yöneliktir.',
  ),
];
