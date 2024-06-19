import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Picker and JSON Parsing Demo',
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
  List<dynamic> user1mess = [];
  List<dynamic> user2mess = [];
  List<dynamic> participant1Messages = [];
  List<dynamic> participant2Messages = [];

  String user1x = '';
  String user2x = '';

  Map<String, int> messageCount = {};
  Map<String, double> averageResponseTime = {};

  void _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      String jsonContent = await File(result.files.single.path!).readAsString();
      Map<String, dynamic> jsonData = jsonDecode(jsonContent);

      // Process messages and remove 'share' field
      List<dynamic> processedMessages = _processMessages(jsonData['messages']);

      setState(() {
        participants = jsonData['participants'];
        messages = processedMessages;
        _calculateMessageCounts();
        user1x = participants.isNotEmpty ? participants[0]['name'] : '';
        user2x = participants.length > 1 ? participants[1]['name'] : '';
      });
    } else {
      // User canceled the picker
    }
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
      print(message);
      String senderName = message['sender_name'];

      if (senderName == participants[0]['name']) {
        participant1Messages.add(message);
      } else if (senderName == participants[1]['name']) {
        participant2Messages.add(message);
      }
    }

    messageCount[participants[0]['name']] = participant1Messages.length;
    messageCount[participants[1]['name']] = participant2Messages.length;

    for (var participant in participants) {
      String participantName = participant['name'];
      List<dynamic> participantMessages = participantName == participants[0]['name'] ? participant1Messages : participant2Messages;

      if (participantMessages.isNotEmpty) {
        double totalResponseTime = 0.0;
        int responseCount = 0;
        String lastSender = '';

        for (int i = 1; i < participantMessages.length; i++) {
          String senderName = participantMessages[i]['sender_name'];

          if (senderName == participantName) {
            int timeDifferenceMs = participantMessages[i]['timestamp_ms'] - participantMessages[i - 1]['timestamp_ms'];
            double timeDifferenceMin = timeDifferenceMs / 60000.0;

            totalResponseTime += timeDifferenceMin;
            responseCount++;
          }
        }

        if (responseCount > 0) {
          averageResponseTime[participantName] = totalResponseTime / responseCount;
        }
      }
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            ListView.builder(
              shrinkWrap: true,
              itemCount: participants.length,
              itemBuilder: (context, index) {
                String participantName = participants[index]['name'];
                int messageCount = index == 0 ? participant1Messages.length : participant2Messages.length;
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('$participantName'),
                    Text('$messageCount'),
                  ],
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Average Response Time (minutes):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              itemCount: participants.length,
              itemBuilder: (context, index) {
                String participantName = participants[index]['name'];
                double avgResponseTime = averageResponseTime[participantName] ?? 0.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text('$participantName'),
                    Text(avgResponseTime.toStringAsFixed(2)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}