import { StatusBar } from "expo-status-bar";
import { useCallback, useEffect, useState } from "react";
import {
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  useColorScheme,
} from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { api, type Note } from "./src/api";
import { colors, radius, space } from "./src/theme";

// Placeholder screen proving mobile -> CloudFront -> Kong -> Go works end to end.
// Replace it with your real app (consider Expo Router once you have several screens).
export default function App() {
  return (
    <SafeAreaProvider>
      <NotesScreen />
    </SafeAreaProvider>
  );
}

function NotesScreen() {
  const scheme = useColorScheme() === "dark" ? "dark" : "light";
  const c = colors[scheme];
  const [notes, setNotes] = useState<Note[]>([]);
  const [title, setTitle] = useState("");
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(() => {
    api.listNotes().then(setNotes).catch((e: Error) => setError(e.message));
  }, []);

  useEffect(refresh, [refresh]);

  async function add() {
    if (!title.trim()) return;
    try {
      await api.createNote(title.trim());
      setTitle("");
      setError(null);
      refresh();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: c.bg }]}>
      <Text style={[styles.h1, { color: c.text }]}>Launchpad</Text>
      <View style={styles.row}>
        <TextInput
          value={title}
          onChangeText={setTitle}
          onSubmitEditing={add}
          placeholder="Write a note"
          placeholderTextColor={c.muted}
          style={[styles.input, { color: c.text, borderColor: c.border, backgroundColor: c.surface }]}
        />
        <Pressable onPress={add} style={styles.button} accessibilityRole="button">
          <Text style={styles.buttonText}>Add</Text>
        </Pressable>
      </View>
      {error && <Text style={{ color: colors.danger }}>{error}</Text>}
      <FlatList
        data={notes}
        keyExtractor={(n) => n.id}
        ListEmptyComponent={<Text style={{ color: c.muted }}>No notes yet.</Text>}
        renderItem={({ item }) => (
          <View style={[styles.item, { backgroundColor: c.surface, borderColor: c.border }]}>
            <Text style={{ color: c.text, flex: 1 }}>{item.title}</Text>
            <Pressable onPress={() => api.deleteNote(item.id).then(refresh)} accessibilityRole="button">
              <Text style={{ color: colors.danger }}>Delete</Text>
            </Pressable>
          </View>
        )}
      />
      <StatusBar style="auto" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space * 2, paddingTop: space * 2 },
  h1: { fontSize: 28, fontWeight: "700", marginBottom: space * 2 },
  row: { flexDirection: "row", gap: space, marginBottom: space * 2 },
  input: { flex: 1, borderWidth: 1, borderRadius: radius, paddingHorizontal: 12, paddingVertical: 10 },
  button: { backgroundColor: colors.primary, borderRadius: radius, paddingHorizontal: 16, justifyContent: "center" },
  buttonText: { color: "#fff", fontWeight: "600" },
  item: {
    flexDirection: "row",
    alignItems: "center",
    padding: 12,
    borderWidth: 1,
    borderRadius: radius,
    marginBottom: space,
  },
});
