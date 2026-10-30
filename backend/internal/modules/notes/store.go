package notes

import (
	"context"
	"sort"
	"sync"
)

// Store is the persistence port. Swap MemoryStore for a real database
// implementation (Postgres, DynamoDB, ...) without touching the service.
type Store interface {
	Put(ctx context.Context, n Note) error
	Get(ctx context.Context, id string) (Note, error)
	List(ctx context.Context) ([]Note, error)
	Delete(ctx context.Context, id string) error
}

// MemoryStore keeps data in process memory. Data is lost on restart/deploy:
// fine for prototyping, replace it before real users arrive.
type MemoryStore struct {
	mu    sync.RWMutex
	notes map[string]Note
}

func NewMemoryStore() *MemoryStore { return &MemoryStore{notes: map[string]Note{}} }

func (s *MemoryStore) Put(_ context.Context, n Note) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.notes[n.ID] = n
	return nil
}

func (s *MemoryStore) Get(_ context.Context, id string) (Note, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	n, ok := s.notes[id]
	if !ok {
		return Note{}, ErrNotFound
	}
	return n, nil
}

func (s *MemoryStore) List(_ context.Context) ([]Note, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]Note, 0, len(s.notes))
	for _, n := range s.notes {
		out = append(out, n)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.After(out[j].CreatedAt) })
	return out, nil
}

func (s *MemoryStore) Delete(_ context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.notes[id]; !ok {
		return ErrNotFound
	}
	delete(s.notes, id)
	return nil
}
