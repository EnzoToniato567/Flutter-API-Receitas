import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api.dart';
import 'splash.dart';

class Formulario extends StatefulWidget {
  const Formulario({super.key, this.receita});

  // a api não oferece GET por ID
  //a  Home entrega a receita selecionada
  final Map<String, dynamic>? receita;

  @override
  State<Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<Formulario> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _ingredientesController = TextEditingController();
  final TextEditingController _modoFazerController = TextEditingController();
  final TextEditingController _imgController = TextEditingController();
  final TextEditingController _custoController = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final receita = widget.receita;
    if (receita != null) {
      _nomeController.text = receita['nome']?.toString() ?? '';
      _ingredientesController.text = receita['ingredientes']?.toString() ?? '';
      _modoFazerController.text = receita['modo_preparo']?.toString() ?? '';
      _imgController.text = receita['url_imagem']?.toString() ?? '';
      _custoController.text = receita['custo']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _ingredientesController.dispose();
    _modoFazerController.dispose();
    _imgController.dispose();
    _custoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlImagem = _imgController.text.trim();
    final uriImagem = Uri.tryParse(urlImagem);
    final imagemValida =
        uriImagem != null &&
        (uriImagem.scheme == 'http' || uriImagem.scheme == 'https') &&
        uriImagem.host.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receita == null ? 'Nova receita' : 'Editar receita'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          spacing: 20,
          children: [
            TextField(
              controller: _nomeController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Nome da receita',
                labelText: 'Nome da receita:',
              ),
            ),
            TextField(
              controller: _ingredientesController,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ingredientes',
                labelText: 'Ingredientes:',
              ),
            ),
            TextField(
              controller: _modoFazerController,
              minLines: 3,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Modo de preparo',
                labelText: 'Modo de preparo:',
              ),
            ),
            TextField(
              controller: _imgController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'URL da imagem',
                labelText: 'URL da imagem (opcional):',
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(
              width: 200,
              height: 180,
              child: imagemValida
                  ? Image.network(
                      urlImagem,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, size: 100),
                    )
                  : const Icon(Icons.image_outlined, size: 100),
            ),
            TextField(
              controller: _custoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Custo R\$ aproximado',
                labelText: 'Custo R\$ aproximado:',
              ),
            ),
            ElevatedButton(
              onPressed: _salvando
                  ? null
                  : widget.receita == null
                  ? enviarReceita
                  : alterarReceita,
              child: Text(
                _salvando
                    ? 'Salvando...'
                    : widget.receita == null
                    ? 'Registrar Receita'
                    : 'Alterar Receita',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (indice) {
          if (indice == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Splash()),
            );
          } else if (indice == 1) {
            Navigator.pop(context);
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

  Future<void> enviarReceita() => _salvar();

  Future<void> alterarReceita() => _salvar();

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    final ingredientes = _ingredientesController.text.trim();
    final modoFazer = _modoFazerController.text.trim();
    final img = _imgController.text.trim();
    final custo = double.tryParse(
      _custoController.text.trim().replaceAll(',', '.'),
    );

    if (nome.isEmpty ||
        ingredientes.isEmpty ||
        modoFazer.isEmpty ||
        custo == null ||
        !custo.isFinite ||
        custo < 0) {
      _mostrarMensagem('Preencha nome, ingredientes, preparo e custo válido.');
      return;
    }
    if (img.isNotEmpty) {
      final uri = Uri.tryParse(img);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        _mostrarMensagem('Informe uma URL de imagem válida.');
        return;
      }
    }

    final dados = <String, dynamic>{
      'nome': nome,
      'ingredientes': ingredientes,
      'modo_preparo': modoFazer,
      'url_imagem': img,
      'custo': custo,
    };
    setState(() => _salvando = true);
    try {
      final id = widget.receita?['id'];
      final url = Uri.parse(
        Api.getEndPoint(
          id == null ? 'receita/cadastrar' : 'receita/atualizar/$id',
        ),
      );
      final headers = {'Content-Type': 'application/json; charset=utf-8'};
      final response =
          await (id == null
                  ? http.post(url, headers: headers, body: jsonEncode(dados))
                  : http.put(url, headers: headers, body: jsonEncode(dados)))
              .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context, true);
      } else {
        _mostrarMensagem(
          'Erro ${response.statusCode} ao salvar receita na API.',
        );
      }
    } catch (_) {
      _mostrarMensagem('Erro ao se comunicar com a API. Confira sua internet.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), duration: const Duration(seconds: 3)),
    );
  }
}
