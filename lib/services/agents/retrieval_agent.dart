import 'dart:developer' as developer;
import '../rag_service.dart';
import '../memory_service.dart';

/// 信息检索 Agent
class RetrievalAgent {
  final RagService _rag = RagService();
  final MemoryService _memory = MemoryService();

  Future<Map<String, String>> retrieve(String userMessage) async {
    String knowledgeContext = '';
    String memoryContext = '';

    final results = await Future.wait([
      _searchKnowledge(userMessage),
      _searchMemory(userMessage),
    ]);

    knowledgeContext = results[0] as String;
    memoryContext = results[1] as String;

    developer.log('【检索Agent】知识库上下文长度: ${knowledgeContext.length}');
    developer.log('【检索Agent】记忆上下文长度: ${memoryContext.length}');

    return {
      'knowledgeContext': knowledgeContext,
      'memoryContext': memoryContext,
    };
  }

  Future<String> _searchKnowledge(String userMessage) async {
    try {
      final entries = _rag.search(userMessage);
      if (entries.isEmpty) return '';
      return _rag.buildKnowledgeContext(entries);
    } catch (e) {
      developer.log('【检索Agent】知识库检索异常: $e');
      return '';
    }
  }

  Future<String> _searchMemory(String userMessage) async {
    try {
      return await _memory.buildMemoryContext(userMessage);
    } catch (e) {
      developer.log('【检索Agent】记忆检索异常: $e');
      return '';
    }
  }
}
