import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

void main() async {
  const notionApiUrl = 'https://api.notion.com/v1/pages';

  Map<String, String> envVariables = Platform.environment;
  final action = envVariables['ACTION'];
  final commitList = envVariables['COMMIT_LIST'];
  final prTitle = envVariables['PR_TITLE'];
  final prAuthor = envVariables['PR_AUTHOR'];
  final prDate = envVariables['PR_DATE'];
  final prNumber = envVariables['PR_NUMBER'];
  final prDescription = envVariables['PR_DESCRIPTION'];
  final notionDB = envVariables['NOTION_DB'];
  final notionSecret = envVariables['NOTION_SECRET'];

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

  final appVersion = await getAppVersion();

  String? commitListFormatted = commitList?.replaceAll('\\n', '\n');

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
        $commitListFormatted 
        $prDescription
      ''';
      case 'PULL_REQUEST_CLOSED':
        return '''
         $prAuthor
         $prTitle
         $prDate
      ''';
      default:
        throw Exception('Unsupported action: $action');
    }
  }

  String messageContent = getMessageContent();

  final headers = {
    'Authorization': 'Bearer $notionSecret',
    'Content-Type': 'application/json',
    'Notion-Version': '2022-06-28',
  };

  final data = {
    "parent": {
      "database_id": notionDB,
    },
    "properties": {
      "Commit": {
        "title": [
          {
            'type': 'text',
            'text': {'content': prTitle ?? 'Default Title'}
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
            'text': {'content': "App Supervisor"}
          }
        ]
      },
      "Mensaje": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': commitListFormatted ?? 'Default Author'}
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
       "Descripcion": {
        "rich_text": [
          {
            'type': 'text',
            'text': {'content': prDescription ?? 'Default Date'}
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
