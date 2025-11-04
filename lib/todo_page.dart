import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
      try {
        if (kDebugMode) {
          print('Tentative d\'ajout de tâche: ${_controller.text.trim()}');
        }

        await FirebaseFirestore.instance.collection('todos').add({
          'text': _controller.text.trim(),
          'done': false,
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'dueDate': Timestamp.fromDate(selectedDate),
        });

        _controller.clear();

        if (kDebugMode) {
          print('Tâche ajoutée avec succès');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors de l\'ajout de la tâche: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Bascule l'état "fait" / "non fait"
  void _toggleDone(String id, bool current) async {
    try {
      if (kDebugMode) {
        print('Mise à jour de la tâche $id: ${!current}');
      }

      await FirebaseFirestore.instance
          .collection('todos')
          .doc(id)
          .update({'done': !current});
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Supprime une tâche
  void _delete(String id) async {
    try {
      if (kDebugMode) {
        print('Suppression de la tâche $id');
      }

      await FirebaseFirestore.instance.collection('todos').doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la suppression: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    final userId = auth.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Erreur: Utilisateur non connecté'),
        ),
      );
    }

    if (kDebugMode) {
      print('Todo page chargée pour l\'utilisateur: $userId');
    }

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
                if (kDebugMode) {
                  print('StreamBuilder state: ${snapshot.connectionState}');
                  print('StreamBuilder hasData: ${snapshot.hasData}');
                  print('StreamBuilder hasError: ${snapshot.hasError}');
                  if (snapshot.hasError) {
                    print('StreamBuilder error: ${snapshot.error}');
                  }
                }

                if (snapshot.hasError) {
                  if (kDebugMode) {
                    print('Erreur Firestore détaillée: ${snapshot.error}');
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          "Erreur de chargement",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des tâches...'),
                      ],
                    ),
                  );
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
