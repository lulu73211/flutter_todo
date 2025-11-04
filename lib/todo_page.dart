import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _controller = TextEditingController();

  /// Ajout d'une tâche dans Firestore
  void _addTodo() async {
    if (_controller.text.isEmpty) return;

    // Ouvre un sélecteur de date
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      FirebaseFirestore.instance.collection('todos').add({
        'text': _controller.text.trim(),
        'done': false,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'dueDate': Timestamp.fromDate(selectedDate),
      });
      _controller.clear();
    }
  }

  /// Bascule l'état "fait" / "non fait"
  void _toggleDone(String id, bool current) {
    FirebaseFirestore.instance
        .collection('todos')
        .doc(id)
        .update({'done': !current});
  }

  /// Supprime une tâche
  void _delete(String id) {
    FirebaseFirestore.instance.collection('todos').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    final userId = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Todos"),
        actions: [
          IconButton(
            onPressed: () async => await auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: "Déconnexion",
          ),
        ],
      ),
      body: Column(
        children: [
          // Champ de saisie + bouton "ajouter"
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: "Nouvelle tâche",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTodo,
                ),
              ],
            ),
          ),

          // Liste des todos de l'utilisateur
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('todos')
                  .where('userId', isEqualTo: userId)
                  .orderBy('dueDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Erreur de chargement"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                      child: Text("Aucune tâche pour l’instant"));
                }

                return ListView(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final bool done = data['done'] ?? false;
                    final Timestamp? dueTimestamp = data['dueDate'];
                    DateTime? dueDate = dueTimestamp?.toDate();

                    // Vérifie si la tâche est en retard
                    final bool isOverdue = dueDate != null &&
                        dueDate.isBefore(DateTime.now()) &&
                        !done;

                    return ListTile(
                      title: Text(
                        data['text'] ?? '',
                        style: TextStyle(
                          color: isOverdue
                              ? Colors.red
                              : null, // 🔴 texte rouge si en retard
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: dueDate != null
                          ? Text(
                              "Échéance : ${dueDate.day}/${dueDate.month}/${dueDate.year}",
                              style: TextStyle(
                                color:
                                    isOverdue ? Colors.red : Colors.grey[600],
                              ),
                            )
                          : null,
                      leading: Checkbox(
                        value: done,
                        onChanged: (_) => _toggleDone(doc.id, done),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(doc.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
