# Tagging Prompt

Classify the note into relevant topics. Use the following taxonomy:

**Topic Categories:**
- `task` - Action items, todos, reminders
- `idea` - Brainstorming, creative thoughts, proposals
- `travel` - Travel plans, locations, trips
- `people:<name>` - Conversations with or about specific people
- `finance` - Money, budgets, expenses, investments
- `health` - Medical, fitness, wellness notes
- `work` - Professional matters, meetings, projects
- `personal` - Personal reflections, diary entries
- `learning` - Educational content, study notes
- `misc` - Other topics

Output JSON format:
```json
{
  "tags": ["task", "work", "people:john"]
}
```

Return 2-5 most relevant tags. Be conservative and accurate.
