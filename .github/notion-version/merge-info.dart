import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

void main() async {
  const notionApiUrl = 'https://api.notion.com/v1/pages';
  String notionSecret = '';
  String databaseId = '';
  Map<String, String> envVariables = Platform.environment;
  final action = envVariables['ACTION'];
  final commitMessage = envVariables['COMMIT_MESSAGES'];
  final prTitle = envVariables['PR_TITLE'];
  final prAuthor = envVariables['PR_AUTHOR'];
  final prDate = envVariables['PR_DATE'];
  final prNumber = envVariables['PR_NUMBER'];

  Future<Map<String, String>> loadEnvironmentVariables() async {
    String content = File('.env.production').readAsStringSync();

    Map<String, String> environmentVariables = {};

    content.split('\n').forEach((line) {
      List<String> parts = line.split('=');

      if (parts.length >= 2 && !line.trim().startsWith('#')) {
        String key = parts[0].trim();
        String value = parts.sublist(1).join('=').trim();

        environmentVariables[key] = value;
      }
    });

    notionSecret = environmentVariables['NOTION_SECRET'] ??
        (throw Exception('NOTION_SECRET is not defined in .env.production'));
    databaseId = environmentVariables['NOTION_DB'] ??
        (throw Exception('NOTION_DB is not defined in .env.production'));

    return {'notionSecret': notionSecret, 'databaseId': databaseId};
  }

 Future<String> getCommitTitles() async {
  final List<String> commitTitles = [];

  try {
    final ProcessResult result = await Process.run(
      'git',
      [
        'log',
        '--pretty=format:%s',
        '${envVariables['GITHUB_SHA'] ?? ''}.${envVariables['GITHUB_SHA'] ?? ''}'
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode == 0) {
      final String output = result.stdout.toString();
      commitTitles.addAll(output.split('\n').where((line) => line.isNotEmpty));

      // Filtrar solo los commits del pull request actual
      final List<String> prCommits = [];
      for (String commit in commitTitles) {
        if (commit.contains('Merge pull request') || commit.contains('fix:')) {
          prCommits.add(commit);
        }
      }

      return prCommits.join('%0A');
    } else {
      print('Error getting commit titles: ${result.stderr}');
    }
  } catch (error) {
    print('Error getting commit titles: $error');
  }

  return '';
}



  final commitMessages = await getCommitTitles();

  Future<String> getAppVersion() async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw Exception("pubspec.yaml file not found");
    }

    final pubspecContent = await pubspecFile.readAsString();
    final pubspecYaml = loadYaml(pubspecContent);

    final appVersion = pubspecYaml['version']?.toString() ?? 'unknown';
    print('App version: $appVersion');
    return appVersion;
  }

  final environmentVariables = await loadEnvironmentVariables();

  notionSecret = environmentVariables['notionSecret'] ?? '';
  databaseId = environmentVariables['databaseId'] ?? '';

  print('notionSecret: $notionSecret');
  print('databaseId: $databaseId');

  final appVersion = await getAppVersion();

  String getMessageContent() {
    if (action == null) {
      return 'Default message for null action';
    }

    switch (action) {
      case 'MERGE':
        return '''
       $prAuthor
       $prTitle
       $prDate
       $commitMessage
       ''';
      case 'PULL_REQUEST_CLOSED':
        return '''
        
       $prAuthor
         $prTitle
        $prDate
        $commitMessage
      ''';
      default:
        throw Exception('Unsupported action: $action');
    }
  }

  String messageContent = getMessageContent();

  print(notionSecret);
  final headers = {
    'Authorization': 'Bearer $notionSecret',
    'Content-Type': 'application/json',
    'Notion-Version': '2022-06-28',
  };

  final data = {
    "parent": {
      "database_id": databaseId,
    },
    "properties": {
      "Commit": {
        "title": [
          {
            'type': 'text',
            'text': {'content': prTitle ?? 'Default Title Commit'}
          }
        ]
      },
      "Version": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': appVersion}
          }
        ]
      },
      "App": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': "Supervisor App"}
          }
        ]
      },
      "Mensaje": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': commitMessages}
          }
        ]
      },
      "Autor": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': prAuthor ?? 'Default Author'}
          }
        ]
      },
      "Fecha": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': prDate ?? 'Default Date'}
          }
        ]
      },
    },
  };

  try {
    final response = await http.post(
      Uri.parse(notionApiUrl),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      print('Notification sent to Notion: $messageContent');
      print('Response body: ${response.body}');
    } else {
      print(
          'Error adding message to Notion. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (error) {
    print('Error sending notification to Notion: $error');
  }
}
