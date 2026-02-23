import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Chat Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AnalyzerDashboardPage(),
    );
  }
}

class AnalyzerDashboardPage extends StatefulWidget {
  const AnalyzerDashboardPage({super.key});

  @override
  State<AnalyzerDashboardPage> createState() => _AnalyzerDashboardPageState();
}

class _AnalyzerDashboardPageState extends State<AnalyzerDashboardPage> {
  final ApiClient _apiClient = ApiClient();

  int _activeViewIndex = 0;
  List<AnalysisSummary> _history = const [];
  AnalysisDetail? _selectedAnalysis;
  bool _isLoadingHistory = true;
  bool _isUploading = false;
  bool _isCheckingNonFollowers = false;
  PlatformFile? _followersFile;
  PlatformFile? _followingFile;
  NonFollowerResult? _nonFollowerResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _error = null;
    });

    try {
      final history = await _apiClient.fetchHistory();
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });

      if (_selectedAnalysis == null && history.isNotEmpty) {
        await _openAnalysis(history.first.id);
      }
    } catch (error) {
      setState(() {
        _isLoadingHistory = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openAnalysis(int id) async {
    try {
      final detail = await _apiClient.fetchAnalysis(id);
      setState(() {
        _selectedAnalysis = detail;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _pickAndAnalyzeFile() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final pickedFile = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: ['json'],
      );

      if (pickedFile == null || pickedFile.files.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final file = pickedFile.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Unable to read the selected JSON file.');
      }

      final rawJson = utf8.decode(bytes);
      final detail = await _apiClient.uploadConversation(
        fileName: file.name,
        jsonString: rawJson,
      );

      await _loadHistory();

      setState(() {
        _selectedAnalysis = detail;
        _isUploading = false;
      });
    } catch (error) {
      setState(() {
        _isUploading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _pickFollowersFile() async {
    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: ['json'],
    );

    if (pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    setState(() {
      _followersFile = pickedFile.files.first;
      _nonFollowerResult = null;
      _error = null;
    });
  }

  Future<void> _pickFollowingFile() async {
    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: ['json'],
    );

    if (pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    setState(() {
      _followingFile = pickedFile.files.first;
      _nonFollowerResult = null;
      _error = null;
    });
  }

  Future<void> _checkNonFollowers() async {
    if (_followersFile == null || _followingFile == null) {
      setState(() {
        _error = 'Please select both followers and following JSON files first.';
      });
      return;
    }

    final followersBytes = _followersFile!.bytes;
    final followingBytes = _followingFile!.bytes;

    if (followersBytes == null || followingBytes == null) {
      setState(() {
        _error = 'Unable to read one of the selected JSON files.';
      });
      return;
    }

    setState(() {
      _isCheckingNonFollowers = true;
      _error = null;
    });

    try {
      final result = await _apiClient.findNonFollowers(
        followersJsonString: utf8.decode(followersBytes),
        followingJsonString: utf8.decode(followingBytes),
      );

      setState(() {
        _nonFollowerResult = result;
        _isCheckingNonFollowers = false;
      });
    } catch (error) {
      setState(() {
        _isCheckingNonFollowers = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _activeViewIndex == 0
        ? 'Instagram Chat Analyzer'
        : 'Follower / Following Checker';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.analytics_outlined),
                  label: Text('Chat Analysis'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.people_outline),
                  label: Text('Followers Check'),
                ),
              ],
              selected: {_activeViewIndex},
              onSelectionChanged: (selection) {
                setState(() {
                  _activeViewIndex = selection.first;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            if (_error != null) const SizedBox(height: 12),
            Expanded(
              child: _activeViewIndex == 0
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 980;
                        if (compact) {
                          return Column(
                            children: [
                              _UploadBar(
                                isUploading: _isUploading,
                                onUploadPressed: _pickAndAnalyzeFile,
                                onRefreshPressed: _loadHistory,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _HistoryPanel(
                                  isLoading: _isLoadingHistory,
                                  items: _history,
                                  selectedId: _selectedAnalysis?.id,
                                  onSelect: _openAnalysis,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _DetailPanel(detail: _selectedAnalysis),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _UploadBar(
                              isUploading: _isUploading,
                              onUploadPressed: _pickAndAnalyzeFile,
                              onRefreshPressed: _loadHistory,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 360,
                                    child: _HistoryPanel(
                                      isLoading: _isLoadingHistory,
                                      items: _history,
                                      selectedId: _selectedAnalysis?.id,
                                      onSelect: _openAnalysis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: _DetailPanel(detail: _selectedAnalysis)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : SingleChildScrollView(
                      child: _FollowBackCheckerCard(
                        followersFileName: _followersFile?.name,
                        followingFileName: _followingFile?.name,
                        isChecking: _isCheckingNonFollowers,
                        result: _nonFollowerResult,
                        onPickFollowers: _pickFollowersFile,
                        onPickFollowing: _pickFollowingFile,
                        onRunCheck: _checkNonFollowers,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBar extends StatelessWidget {
  const _UploadBar({
    required this.isUploading,
    required this.onUploadPressed,
    required this.onRefreshPressed,
  });

  final bool isUploading;
  final Future<void> Function() onUploadPressed;
  final Future<void> Function() onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.analytics_outlined),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Upload an Instagram messages JSON to analyze and save to SQL database.'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isUploading ? null : onUploadPressed,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(isUploading ? 'Analyzing...' : 'Upload JSON'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onRefreshPressed,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.isLoading,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final bool isLoading;
  final List<AnalysisSummary> items;
  final int? selectedId;
  final Future<void> Function(int id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Analyses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? const Center(
                          child: Text('No analyses yet. Upload your first chat file.'),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final selected = item.id == selectedId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: selected
                                  ? Theme.of(context).colorScheme.secondaryContainer
                                  : null,
                              child: ListTile(
                                onTap: () => onSelect(item.id),
                                title: Text(item.fileName),
                                subtitle: Text(
                                  '${item.participantOne} vs ${item.participantTwo}\n'
                                  'Total messages: ${item.totalMessages}',
                                ),
                                trailing: Text('#${item.id}'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowBackCheckerCard extends StatefulWidget {
  const _FollowBackCheckerCard({
    required this.followersFileName,
    required this.followingFileName,
    required this.isChecking,
    required this.result,
    required this.onPickFollowers,
    required this.onPickFollowing,
    required this.onRunCheck,
  });

  final String? followersFileName;
  final String? followingFileName;
  final bool isChecking;
  final NonFollowerResult? result;
  final Future<void> Function() onPickFollowers;
  final Future<void> Function() onPickFollowing;
  final Future<void> Function() onRunCheck;

  @override
  State<_FollowBackCheckerCard> createState() => _FollowBackCheckerCardState();
}

class _FollowBackCheckerCardState extends State<_FollowBackCheckerCard> {
  String _notFollowingYouSearchQuery = '';
  String _youDontFollowSearchQuery = '';

  List<String> _filterUsers(List<String> source, String queryText) {
    if (queryText.trim().isEmpty) {
      return source;
    }

    final query = queryText.trim().toLowerCase();
    return source.where((item) => item.toLowerCase().contains(query)).toList();
  }

  Future<void> _copyResults(List<String> items) async {
    if (items.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: items.join('\n')));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${items.length} usernames to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notFollowingBack = widget.result?.notFollowingBack ?? const <String>[];
    final youDontFollowBack = widget.result?.youDontFollowBack ?? const <String>[];

    final filteredNotFollowingBack = _filterUsers(
      notFollowingBack,
      _notFollowingYouSearchQuery,
    );

    final filteredYouDontFollowBack = _filterUsers(
      youDontFollowBack,
      _youDontFollowSearchQuery,
    );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follower Check',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Upload followers and following JSON files to compare both directions.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onPickFollowers,
                  icon: const Icon(Icons.people_outline),
                  label: Text(widget.followersFileName ?? 'Select Followers JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onPickFollowing,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(widget.followingFileName ?? 'Select Following JSON'),
                ),
                FilledButton.icon(
                  onPressed: widget.isChecking ? null : widget.onRunCheck,
                  icon: widget.isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(widget.isChecking ? 'Checking...' : 'Check Non-Followers'),
                ),
              ],
            ),
            if (widget.result != null) ...[
              const SizedBox(height: 12),
              Text(
                'Followers: ${widget.result!.totalFollowers} • Following: ${widget.result!.totalFollowing}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Not following you back (${widget.result!.notFollowingBackCount})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search in not-following-you-back',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _notFollowingYouSearchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: filteredNotFollowingBack.isEmpty
                    ? null
                    : () => _copyResults(filteredNotFollowingBack),
                icon: const Icon(Icons.copy_all_outlined),
                label: Text('Copy ${filteredNotFollowingBack.length} usernames'),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: filteredNotFollowingBack.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No usernames match this filter.'),
                      )
                    : ListView.builder(
                        itemCount: filteredNotFollowingBack.length,
                        itemBuilder: (context, index) {
                          final username = filteredNotFollowingBack[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_remove_outlined),
                            title: Text(username),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'You are not following back (${widget.result!.youDontFollowBackCount})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search in you-dont-follow-back',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _youDontFollowSearchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: filteredYouDontFollowBack.isEmpty
                    ? null
                    : () => _copyResults(filteredYouDontFollowBack),
                icon: const Icon(Icons.copy_all_outlined),
                label: Text('Copy ${filteredYouDontFollowBack.length} usernames'),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: filteredYouDontFollowBack.isEmpty
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No usernames match this filter.'),
                      )
                    : ListView.builder(
                        itemCount: filteredYouDontFollowBack.length,
                        itemBuilder: (context, index) {
                          final username = filteredYouDontFollowBack[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(username),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.detail});

  final AnalysisDetail? detail;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: const Center(
          child: Text('Select an analysis from the left to view full details.'),
        ),
      );
    }

    final participantOne = detail!.participantOne;
    final participantTwo = detail!.participantTwo;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail!.fileName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text('Analysis ID #${detail!.id}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricCard(
                    title: 'Messages ($participantOne)',
                    value: '${detail!.messageCounts[participantOne] ?? 0}',
                    icon: Icons.message_outlined,
                  ),
                  _MetricCard(
                    title: 'Messages ($participantTwo)',
                    value: '${detail!.messageCounts[participantTwo] ?? 0}',
                    icon: Icons.message_outlined,
                  ),
                  _MetricCard(
                    title: 'Avg response ($participantOne)',
                    value:
                        '${(detail!.averageResponseMinutes[participantOne] ?? 0).toStringAsFixed(2)} min',
                    icon: Icons.schedule,
                  ),
                  _MetricCard(
                    title: 'Avg response ($participantTwo)',
                    value:
                        '${(detail!.averageResponseMinutes[participantTwo] ?? 0).toStringAsFixed(2)} min',
                    icon: Icons.schedule,
                  ),
                  _MetricCard(
                    title: 'Avg sentiment ($participantOne)',
                    value: (detail!.averageSentiment[participantOne] ?? 0).toStringAsFixed(2),
                    icon: Icons.sentiment_satisfied_alt,
                  ),
                  _MetricCard(
                    title: 'Avg sentiment ($participantTwo)',
                    value: (detail!.averageSentiment[participantTwo] ?? 0).toStringAsFixed(2),
                    icon: Icons.sentiment_satisfied_alt,
                  ),
                  _MetricCard(
                    title: 'Total Messages',
                    value: '${detail!.totalMessages}',
                    icon: Icons.forum_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApiClient {
  Future<List<AnalysisSummary>> fetchHistory() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/analyses'));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch analysis history (${response.statusCode}).');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['analyses'] as List<dynamic>? ?? [];

    return items
        .map((item) => AnalysisSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AnalysisDetail> fetchAnalysis(int id) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/analyses/$id'));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch analysis #$id (${response.statusCode}).');
    }

    return AnalysisDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnalysisDetail> uploadConversation({
    required String fileName,
    required String jsonString,
  }) async {
    final conversation = jsonDecode(jsonString);
    final body = jsonEncode({
      'fileName': fileName,
      'conversation': conversation,
    });

    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/analyses'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 201) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = payload?['message'] ?? 'Analysis failed.';
      throw Exception('$message (${response.statusCode})');
    }

    return AnalysisDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NonFollowerResult> findNonFollowers({
    required String followersJsonString,
    required String followingJsonString,
  }) async {
    final body = jsonEncode({
      'followers': jsonDecode(followersJsonString),
      'following': jsonDecode(followingJsonString),
    });

    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/non-followers'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>?;
      final message = payload?['message'] ?? 'Unable to compare followers/following.';
      throw Exception('$message (${response.statusCode})');
    }

    return NonFollowerResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class NonFollowerResult {
  NonFollowerResult({
    required this.totalFollowers,
    required this.totalFollowing,
    required this.notFollowingBackCount,
    required this.notFollowingBack,
    required this.youDontFollowBackCount,
    required this.youDontFollowBack,
  });

  final int totalFollowers;
  final int totalFollowing;
  final int notFollowingBackCount;
  final List<String> notFollowingBack;
  final int youDontFollowBackCount;
  final List<String> youDontFollowBack;

  factory NonFollowerResult.fromJson(Map<String, dynamic> json) {
    return NonFollowerResult(
      totalFollowers: (json['totalFollowers'] as num?)?.toInt() ?? 0,
      totalFollowing: (json['totalFollowing'] as num?)?.toInt() ?? 0,
      notFollowingBackCount: (json['notFollowingBackCount'] as num?)?.toInt() ?? 0,
      notFollowingBack: (json['notFollowingBack'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      youDontFollowBackCount: (json['youDontFollowBackCount'] as num?)?.toInt() ?? 0,
      youDontFollowBack: (json['youDontFollowBack'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class AnalysisSummary {
  AnalysisSummary({
    required this.id,
    required this.fileName,
    required this.participantOne,
    required this.participantTwo,
    required this.totalMessages,
  });

  final int id;
  final String fileName;
  final String participantOne;
  final String participantTwo;
  final int totalMessages;

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    final participants = (summary['participants'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final totals = summary['totals'] as Map<String, dynamic>;

    return AnalysisSummary(
      id: json['id'] as int,
      fileName: json['fileName'] as String,
      participantOne: participants.isNotEmpty ? participants[0] : 'User 1',
      participantTwo: participants.length > 1 ? participants[1] : 'User 2',
      totalMessages: (totals['totalMessages'] as num).toInt(),
    );
  }
}

class AnalysisDetail {
  AnalysisDetail({
    required this.id,
    required this.fileName,
    required this.participantOne,
    required this.participantTwo,
    required this.totalMessages,
    required this.messageCounts,
    required this.averageResponseMinutes,
    required this.averageSentiment,
  });

  final int id;
  final String fileName;
  final String participantOne;
  final String participantTwo;
  final int totalMessages;
  final Map<String, int> messageCounts;
  final Map<String, double> averageResponseMinutes;
  final Map<String, double> averageSentiment;

  factory AnalysisDetail.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    final participants = (summary['participants'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final totals = summary['totals'] as Map<String, dynamic>;
    final metrics = summary['metrics'] as Map<String, dynamic>;

    return AnalysisDetail(
      id: json['id'] as int,
      fileName: json['fileName'] as String,
      participantOne: participants.isNotEmpty ? participants[0] : 'User 1',
      participantTwo: participants.length > 1 ? participants[1] : 'User 2',
      totalMessages: (totals['totalMessages'] as num).toInt(),
      messageCounts: _toIntMap(metrics['messageCounts']),
      averageResponseMinutes: _toDoubleMap(metrics['averageResponseMinutes']),
      averageSentiment: _toDoubleMap(metrics['averageSentiment']),
    );
  }

  static Map<String, int> _toIntMap(dynamic value) {
    final map = (value as Map<String, dynamic>? ?? {});
    return map.map((key, val) => MapEntry(key, (val as num).toInt()));
  }

  static Map<String, double> _toDoubleMap(dynamic value) {
    final map = (value as Map<String, dynamic>? ?? {});
    return map.map((key, val) => MapEntry(key, (val as num).toDouble()));
  }
}
