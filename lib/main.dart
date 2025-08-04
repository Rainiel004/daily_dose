import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

Future<void> saveNotes(List<Note> notes, List<Note> deletedNotes) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Convert to JSON and encode to string
  final notesJson = json.encode(notes.map((n) => n.toJson()).toList());
  final deletedJson = json.encode(deletedNotes.map((n) => n.toJson()).toList());
  
  await prefs.setString('notes', notesJson);
  await prefs.setString('recentlyDeletedNotes', deletedJson);
}

Future<void> loadNotes(List<Note> notes, List<Note> deletedNotes) async {
  final prefs = await SharedPreferences.getInstance();
  
  notes.clear();
  deletedNotes.clear();
  
  // Decode JSON strings
  final notesJson = prefs.getString('notes');
  final deletedJson = prefs.getString('recentlyDeletedNotes');
  
  if (notesJson != null) {
    final decoded = json.decode(notesJson) as List<dynamic>;
    notes.addAll(decoded.map((e) => Note.fromJson(e as Map<String, dynamic>)));
  }
  
  if (deletedJson != null) {
    final decoded = json.decode(deletedJson) as List<dynamic>;
    deletedNotes.addAll(decoded.map((e) => Note.fromJson(e as Map<String, dynamic>)));
  }
}

void main() {
  runApp(const NotesApp());
}

class Note {
  final String id;
  String title;
  String content;
  DateTime lastUpdated;
  Color color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.lastUpdated,
    this.color = Colors.yellow,
  });

  // Use toARGB32 for serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'lastUpdated': lastUpdated.toIso8601String(),
        'color': color.toARGB32(), // <-- updated
      };

  static Note fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        lastUpdated: DateTime.parse(json['lastUpdated']),
        color: Color.fromARGB(
          (json['color'] >> 24) & 0xFF,
          (json['color'] >> 16) & 0xFF,
          (json['color'] >> 8) & 0xFF,
          json['color'] & 0xFF,
        ), // <-- updated
      );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const NotesListScreen(),
    );
  }
}

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final List<Note> _notes = [];
  final List<Note> _recentlyDeletedNotes = [];

  @override
  void initState() {
    super.initState();
    loadNotes(_notes, _recentlyDeletedNotes).then((_) {
      setState(() {});
    });
  }

  Future<void> _saveNotes() async {
    await saveNotes(_notes, _recentlyDeletedNotes);
  }

  void _addNote(Note newNote) async {
    setState(() {
      _notes.add(newNote);
    });
    await _saveNotes();
  }

  void _updateNote(String id, Note updatedNote) {
    setState(() {
      final index = _notes.indexWhere((note) => note.id == id);
      if (index != -1) {
        _notes[index] = updatedNote;
      }
    });
    _saveNotes();
  }

  void _deleteNote(String id) {
    setState(() {
      final index = _notes.indexWhere((note) => note.id == id);
      if (index != -1) {
        _recentlyDeletedNotes.add(_notes[index]); // Add to recycle bin
        _notes.removeAt(index);
      }
    });
    _saveNotes();
  }

  void _restoreNote(Note note) {
    setState(() {
      _notes.add(note);
      _recentlyDeletedNotes.removeWhere((n) => n.id == note.id);
    });
    _saveNotes();
  }

  void _undoDelete() {
    if (_recentlyDeletedNotes.isNotEmpty) {
      setState(() {
        _notes.add(_recentlyDeletedNotes.removeLast());
      });
      _saveNotes();
    }
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showRecentlyDeletedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recently Deleted Notes'),
          content: SizedBox(
            width: double.maxFinite,
            child: _recentlyDeletedNotes.isEmpty
                ? const Text('No recently deleted notes.')
                : ListView.builder(
                    itemCount: _recentlyDeletedNotes.length,
                    itemBuilder: (context, index) {
                      final note = _recentlyDeletedNotes[index];
                      return ListTile(
                        title: Text(note.title),
                        subtitle: Text(
                          _formatDate(note.lastUpdated),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.undo),
                          tooltip: 'Restore',
                          onPressed: () {
                            Navigator.pop(context);
                            _restoreNote(note);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Notes'),
        actions: [
          if (_recentlyDeletedNotes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Restore deleted note',
              onPressed: _undoDelete,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Recently Deleted',
            onPressed: _showRecentlyDeletedDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoteFormScreen(),
            ),
          );
          if (result != null && result is Note) {
            _addNote(result);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.note_add,
                    size: 50,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No notes yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap the + button to add your first note',
                    style: TextStyle(fontSize: 16),
                  ),
                 const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NoteFormScreen(),
                ),
              );
              if (result != null && result is Note) {
                _addNote(result);
              }
            },
            child: const Text('Create First Note'),
          ),
                            ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteFormScreen(
                          note: note,
                          isEditing: true,
                        ),
                      ),
                    );
                    if (result != null && result is Note) {
                      _updateNote(note.id, result);
                    }
                  },
                  child: Card(
                    // ignore: deprecated_member_use
                    color: note.color.withOpacity(0.2),
                    elevation: 2,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                child: Text(
                                  note.content,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(note.lastUpdated),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () {
                              _deleteNote(note.id);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class NoteFormScreen extends StatefulWidget {
  final Note? note;
  final bool isEditing;

  const NoteFormScreen({
    super.key,
    this.note,
    this.isEditing = false,
  });

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late Color _selectedColor;

  final List<Color> _colorOptions = [
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.note?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _selectedColor = widget.note?.color ?? Colors.yellow;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_formKey.currentState!.validate()) {
      final note = Note(
        id: widget.note?.id ?? DateTime.now().toString(),
        title: _titleController.text,
        content: _contentController.text,
        lastUpdated: DateTime.now(),
        color: _selectedColor,
      );
      Navigator.pop(context, note);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Note' : 'Add Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Note Color:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorOptions.length,
                  itemBuilder: (context, index) {
                    final color = _colorOptions[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _saveNote,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 50),
                  ),
                  child: Text(
                    widget.isEditing ? 'Update' : 'Save',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}