import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../api.dart';
import 'formulario.dart';
import 'splash.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> receitas = [], filtradas = [];
  bool _carregando = true;
  String? _erro;
  String _filtroNome = '';
  final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    carregarReceitas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receitas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: carregarReceitas,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          spacing: 12,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Filtrar por nome ou ingrediente',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: filtroNome,
            ),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erro != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_erro!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: carregarReceitas,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : filtradas.isEmpty
                  ? Center(
                      child: Text(
                        receitas.isEmpty
                            ? 'Nenhuma receita encontrada. Toque em Nova para cadastrar.'
                            : 'Nenhuma receita corresponde ao filtro.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: carregarReceitas,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtradas.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtradas[index];
                          final nome = item['nome']?.toString() ?? 'Receita';
                          final img = item['url_imagem']?.toString() ?? '';
                          final id = int.tryParse('${item['id']}');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            onTap: id == null ? null : () => detalhes(id),
                            leading: SizedBox(
                              width: 56,
                              height: 56,
                              child: _imagem(img),
                            ),
                            title: Text(nome),
                            subtitle: Text(_formatarCusto(item['custo'])),
                            trailing: IconButton(
                              tooltip: 'Excluir $nome',
                              onPressed: id == null
                                  ? null
                                  : () => confirmaExcluir(id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (indice) {
          if (indice == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Splash()),
            );
          } else if (indice == 2) {
            _abrirFormulario();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'Splash'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Nova'),
        ],
      ),
    );
  }

  Widget _imagem(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return const Icon(Icons.restaurant, size: 32);
    }
    return Image.network(
      url,
      width: 56,
      height: 56,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.image_not_supported),
    );
  }

  String _formatarCusto(dynamic valor) {
    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse(valor?.toString() ?? '');
    return numero == null ? 'Custo não informado' : _moeda.format(numero);
  }

  Future<void> _abrirFormulario([Map<String, dynamic>? receita]) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => Formulario(receita: receita)),
    );
    if (alterou == true && mounted) {
      await carregarReceitas();
      if (!mounted) return;
      _mostrarMensagem(
        receita == null
            ? 'Receita cadastrada com sucesso.'
            : 'Receita atualizada com sucesso.',
      );
    }
  }

  Future<void> carregarReceitas() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final url = Uri.parse(Api.getEndPoint('receita/listar'));
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Erro ${response.statusCode} ao consultar a API.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final lista = data is List
          ? data
          : (data is Map ? data['receitas'] : null);
      if (lista is! List) {
        throw const FormatException('Resposta inválida da API.');
      }
      if (!mounted) return;
      setState(() {
        receitas = lista
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _aplicarFiltros();
      });
    } catch (erro) {
      if (!mounted) return;
      setState(
        () => _erro = 'Não foi possível carregar as receitas. Verifique a internet e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void detalhes(int id) {
    final receita = receitas.where(
      (item) => int.tryParse('${item['id']}') == id,
    );
    if (receita.isEmpty) return;
    final item = receita.first;
    final img = item['url_imagem']?.toString() ?? '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item['nome']?.toString() ?? 'Receita'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Center(
                  child: SizedBox(width: 150, height: 150, child: _imagem(img)),
                ),
                Text('Ingredientes: ${item['ingredientes'] ?? ''}'),
                Text('Modo de preparo: ${item['modo_preparo'] ?? ''}'),
                Text('Custo aproximado: ${_formatarCusto(item['custo'])}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _abrirFormulario(item);
            },
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  void confirmaExcluir(int id) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirma exclusão'),
        content: Text('Deseja realmente excluir a receita número $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              excluirReceita(id);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> excluirReceita(int id) async {
    try {
      final url = Uri.parse(Api.getEndPoint('receita/excluir/$id'));
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        carregarReceitas();
      } else {
        _mostrarMensagem('Erro ${response.statusCode} ao excluir receita.');
      }
    } catch (_) {
      _mostrarMensagem('Erro ao se comunicar com a API.');
    }
  }

  void filtroNome(String? nome) {
    _filtroNome = nome?.trim() ?? '';
    setState(_aplicarFiltros);
  }

  void _aplicarFiltros() {
    final busca = _filtroNome.toLowerCase();
    filtradas = receitas.where((receita) {
      final nome = receita['nome']?.toString().toLowerCase() ?? '';
      final ingredientes =
          receita['ingredientes']?.toString().toLowerCase() ?? '';
      return nome.contains(busca) || ingredientes.contains(busca);
    }).toList();
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), duration: const Duration(seconds: 3)),
    );
  }
}
