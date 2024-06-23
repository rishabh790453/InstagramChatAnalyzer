import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:sentiment_dart/sentiment_dart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Chat Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<dynamic> participants = [];
  List<dynamic> messages = [];
  
  List<dynamic> participant1Messages = [];
  List<dynamic> participant2Messages = [];

  List<int> totaltimesuser1 = [];
  List<int> totaltimesuser2 = [];
  double avgtimesuser1 = 0;
  double avgtimesuser2 = 0;
  int sumtimesuser1 = 0;
  int sumtimesuser2 = 0;

  double avgSentimentUser1 = 0;
  double avgSentimentUser2 = 0;
  
  Map<String, int> messageCount = {};
  Map<String, double> averageResponseTime = {};

  void _openFilePicker() async {
    // Resetting state
    setState(() {
      participants = [];
      messages = [];
      participant1Messages = [];
      participant2Messages = [];
      totaltimesuser1 = [];
      totaltimesuser2 = [];
      avgtimesuser1 = 0;
      avgtimesuser2 = 0;
      sumtimesuser1 = 0;
      sumtimesuser2 = 0;
      avgSentimentUser1 = 0;
      avgSentimentUser2 = 0;
      messageCount = {};
      averageResponseTime = {};
    });

    final input = html.FileUploadInputElement();
    input.accept = '.json';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final reader = html.FileReader();
        reader.readAsText(file);

        reader.onLoadEnd.listen((e) {
          final jsonContent = reader.result as String?;
          if (jsonContent != null) {
            final jsonData = jsonDecode(jsonContent);

            List<dynamic> processedMessages = _processMessages(jsonData['messages']);

            setState(() {
              participants = jsonData['participants'];
              messages = processedMessages;
              _calculateMessageCounts();
              _calculateAverageSentiments();
            });
          }
        });
      }
    });
  }

  List<dynamic> _processMessages(List<dynamic> messages) {
    List<dynamic> processedMessages = [];

    for (var message in messages) {
      var processedMessage = Map<String, dynamic>.from(message);

      if (processedMessage.containsKey('share')) {
        processedMessage.remove('share');
      }

      processedMessages.add(processedMessage);
    }

    return processedMessages;
  }

  void _calculateMessageCounts() {
    messageCount.clear();
    averageResponseTime.clear();

    for (var participant in participants) {
      messageCount[participant['name']] = 0;
      averageResponseTime[participant['name']] = 0.0;
    }

    for (var message in messages) {
      String senderName = message['sender_name'];

      if (senderName == participants[0]['name']) {
        participant1Messages.add(message);
      } else if (senderName == participants[1]['name']) {
        participant2Messages.add(message);
      }
    }

    messageCount[participants[0]['name']] = participant1Messages.length;
    messageCount[participants[1]['name']] = participant2Messages.length;

    for (int i = messages.length - 1; i > 0; i--) {
      if (messages[i]['sender_name'] != messages[i - 1]['sender_name']) {
        if (messages[i - 1]['sender_name'] == participants[0]['name']) {
          totaltimesuser1.add((messages[i - 1]['timestamp_ms'] - messages[i]['timestamp_ms']));
        } else {
          totaltimesuser2.add((messages[i - 1]['timestamp_ms'] - messages[i]['timestamp_ms']));
        }
      }
    }

    for (int x in totaltimesuser1) {
      sumtimesuser1 += x;
    }
    for (int x in totaltimesuser2) {
      sumtimesuser2 += x;
    }

    avgtimesuser1 = (sumtimesuser1 / (totaltimesuser1.length * 60000));
    avgtimesuser2 = (sumtimesuser2 / (totaltimesuser2.length * 60000));
  }

  void _calculateAverageSentiments() {
    double totalSentimentUser1 = 0;
    int user1count = 0;
    double totalSentimentUser2 = 0;
    int user2count = 0;

    for (var message in participant1Messages) {
      if (message['content'] != null) {
        var analysis = Sentiment.analysis(message['content']);
        if (analysis.score != 0) {
          totalSentimentUser1 += analysis.score;
          user1count++;
        }
      }
    }

    for (var message in participant2Messages) {
      if (message['content'] != null) {
        var analysis = Sentiment.analysis(message['content']);
        if (analysis.score != 0) {
          totalSentimentUser2 += analysis.score;
          user2count++;
        }
      }
    }

    if (user1count > 0) {
      avgSentimentUser1 = totalSentimentUser1 / user1count;
    }

    if (user2count > 0) {
      avgSentimentUser2 = totalSentimentUser2 / user2count;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instagram Chat Analyzer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _openFilePicker,
              child: Text('Open Instagram Chat'),
            ),
            SizedBox(height: 20),
            Text(
              'Message Counts:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: participants.map((participant) {
                int messageCount = participant['name'] == participants[0]['name'] ? participant1Messages.length : participant2Messages.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('${participant['name']}: $messageCount'),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Text(
              'Average Response Time (minutes):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${participants.isNotEmpty ? participants[0]['name'] : 'User 1'}: ${participants.isNotEmpty ? avgtimesuser1.toStringAsFixed(2) : ''} minutes',
                ),
                Text(
                  '${participants.isNotEmpty ? participants[1]['name'] : 'User 2'}: ${participants.isNotEmpty ? avgtimesuser2.toStringAsFixed(2) : ''} minutes',
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Average Sentiment:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${participants.isNotEmpty ? participants[0]['name'] : 'User 1'}: ${participants.isNotEmpty ? avgSentimentUser1.toStringAsFixed(2) : ''}',
                ),
                Text(
                  '${participants.isNotEmpty ? participants[1]['name'] : 'User 2'}: ${participants.isNotEmpty ? avgSentimentUser2.toStringAsFixed(2) : ''}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
