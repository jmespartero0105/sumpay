import '../models/message_models.dart';

/// Seeded conversations and message threads.
class DummyMessages {
  const DummyMessages._();

  static const List<Map<String, dynamic>> conversationsJson =
      <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'CONV-01',
      'title': 'Barangay Office',
      'subtitle': 'Official channel • Talay',
      'lastMessage':
          'Rescue Team Bravo is en route to your location. Stay where you are.',
      'minutesAgo': 6,
      'unreadCount': 2,
      'priority': 'critical',
      'transport': 'loRa',
      'isOfficial': true,
      'isGroup': false,
      'participants': 2,
    },
    <String, dynamic>{
      'id': 'CONV-02',
      'title': 'Purok 4 Residents',
      'subtitle': 'Group • 38 members',
      'lastMessage': 'Aling Nena: Naa pa bay tubig sa evacuation centre?',
      'minutesAgo': 24,
      'unreadCount': 5,
      'priority': 'normal',
      'transport': 'mesh',
      'isOfficial': false,
      'isGroup': true,
      'participants': 38,
    },
    <String, dynamic>{
      'id': 'CONV-03',
      'title': 'Volunteer Team Alpha',
      'subtitle': 'Group • 12 members',
      'lastMessage': 'Jomar: Two more households cleared in Sitio Riverside.',
      'minutesAgo': 51,
      'unreadCount': 0,
      'priority': 'high',
      'transport': 'loRa',
      'isOfficial': false,
      'isGroup': true,
      'participants': 12,
    },
    <String, dynamic>{
      'id': 'CONV-04',
      'title': 'Kagawad Elena Rubio',
      'subtitle': 'Barangay Official',
      'lastMessage': 'Please confirm your household headcount when you can.',
      'minutesAgo': 128,
      'unreadCount': 0,
      'priority': 'normal',
      'transport': 'loRa',
      'isOfficial': true,
      'isGroup': false,
      'participants': 2,
    },
    <String, dynamic>{
      'id': 'CONV-05',
      'title': 'Roberto Fernandez',
      'subtitle': 'Emergency contact',
      'lastMessage': 'Message queued — will send when a connection is available.',
      'minutesAgo': 240,
      'unreadCount': 0,
      'priority': 'low',
      'transport': 'offline',
      'isOfficial': false,
      'isGroup': false,
      'participants': 2,
    },
  ];

  static const Map<String, List<Map<String, dynamic>>> threadsJson =
      <String, List<Map<String, dynamic>>>{
    'CONV-01': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MSG-101',
        'conversationId': 'CONV-01',
        'senderName': 'Barangay Office',
        'body':
            'We received your SOS beacon (SOS-4471). Confirm the number of persons needing assistance.',
        'minutesAgo': 13,
        'isMine': false,
        'status': 'delivered',
        'priority': 'critical',
        'transport': 'loRa',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-102',
        'conversationId': 'CONV-01',
        'senderName': 'You',
        'body': 'One elderly person, unconscious but breathing.',
        'minutesAgo': 11,
        'isMine': true,
        'status': 'delivered',
        'priority': 'critical',
        'transport': 'loRa',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-103',
        'conversationId': 'CONV-01',
        'senderName': 'You',
        'body': 'Sending our exact position now.',
        'minutesAgo': 10,
        'isMine': true,
        'status': 'delivered',
        'priority': 'critical',
        'transport': 'loRa',
        'attachment': <String, dynamic>{
          'id': 'ATT-1',
          'name': 'Pinned location',
          'kind': 'location',
          'sizeLabel': '9.30684, 123.30193',
        },
      },
      <String, dynamic>{
        'id': 'MSG-104',
        'conversationId': 'CONV-01',
        'senderName': 'Barangay Office',
        'body': 'Copy. Rescue Team Bravo dispatched, ETA 8 minutes.',
        'minutesAgo': 7,
        'isMine': false,
        'status': 'delivered',
        'priority': 'critical',
        'transport': 'loRa',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-105',
        'conversationId': 'CONV-01',
        'senderName': 'Barangay Office',
        'body':
            'Rescue Team Bravo is en route to your location. Stay where you are.',
        'minutesAgo': 6,
        'isMine': false,
        'status': 'delivered',
        'priority': 'critical',
        'transport': 'loRa',
        'attachment': null,
      },
    ],
    'CONV-02': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MSG-201',
        'conversationId': 'CONV-02',
        'senderName': 'Purok Leader Tino',
        'body': 'Headcount for Purok 4 is ongoing. Please reply with your household status.',
        'minutesAgo': 62,
        'isMine': false,
        'status': 'delivered',
        'priority': 'high',
        'transport': 'mesh',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-202',
        'conversationId': 'CONV-02',
        'senderName': 'You',
        'body': 'Five persons in our household, all accounted for.',
        'minutesAgo': 58,
        'isMine': true,
        'status': 'relayed',
        'priority': 'normal',
        'transport': 'mesh',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-203',
        'conversationId': 'CONV-02',
        'senderName': 'Aling Nena',
        'body': 'Naa pa bay tubig sa evacuation centre?',
        'minutesAgo': 24,
        'isMine': false,
        'status': 'delivered',
        'priority': 'normal',
        'transport': 'mesh',
        'attachment': null,
      },
    ],
    'CONV-03': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MSG-301',
        'conversationId': 'CONV-03',
        'senderName': 'Team Lead Arnel',
        'body': 'Sweep Sitio Riverside first, then move to the ridge.',
        'minutesAgo': 74,
        'isMine': false,
        'status': 'delivered',
        'priority': 'high',
        'transport': 'loRa',
        'attachment': null,
      },
      <String, dynamic>{
        'id': 'MSG-302',
        'conversationId': 'CONV-03',
        'senderName': 'Jomar',
        'body': 'Two more households cleared in Sitio Riverside.',
        'minutesAgo': 51,
        'isMine': false,
        'status': 'delivered',
        'priority': 'high',
        'transport': 'loRa',
        'attachment': <String, dynamic>{
          'id': 'ATT-2',
          'name': 'Voice report',
          'kind': 'voice',
          'sizeLabel': '0:24',
        },
      },
    ],
    'CONV-04': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MSG-401',
        'conversationId': 'CONV-04',
        'senderName': 'Kagawad Elena Rubio',
        'body': 'Please confirm your household headcount when you can.',
        'minutesAgo': 128,
        'isMine': false,
        'status': 'delivered',
        'priority': 'normal',
        'transport': 'loRa',
        'attachment': null,
      },
    ],
    'CONV-05': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'MSG-501',
        'conversationId': 'CONV-05',
        'senderName': 'You',
        'body': 'We are safe at the evacuation centre. Do not worry.',
        'minutesAgo': 240,
        'isMine': true,
        'status': 'queued',
        'priority': 'normal',
        'transport': 'offline',
        'attachment': null,
      },
    ],
  };

  static List<Conversation> get conversations => conversationsJson
      .map((Map<String, dynamic> json) => Conversation.fromJson(json))
      .toList();

  static Map<String, List<ChatMessage>> get threads {
    return threadsJson.map(
      (String key, List<Map<String, dynamic>> value) =>
          MapEntry<String, List<ChatMessage>>(
        key,
        value
            .map((Map<String, dynamic> json) => ChatMessage.fromJson(json))
            .toList(),
      ),
    );
  }

  /// Canned replies offered above the composer for fast, low-bandwidth replies.
  static const List<String> quickReplies = <String>[
    'We are safe',
    'Need assistance',
    'On the way',
    'Copy that',
    'Send supplies',
  ];
}
