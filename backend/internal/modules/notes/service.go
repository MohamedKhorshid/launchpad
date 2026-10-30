package notes

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	ErrNotFound = errors.New("not found")
	ErrInvalid  = errors.New("invalid input")
)

type Note struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"createdAt"`
}

type CreateInput struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type Service struct{ store Store }

func NewService(store Store) *Service { return &Service{store: store} }

func (s *Service) Create(ctx context.Context, in CreateInput) (Note, error) {
	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" || len(in.Title) > 200 {
		return Note{}, fmt.Errorf("%w: title is required (max 200 chars)", ErrInvalid)
	}
	n := Note{ID: newID(), Title: in.Title, Body: in.Body, CreatedAt: time.Now().UTC()}
	return n, s.store.Put(ctx, n)
}

func (s *Service) Get(ctx context.Context, id string) (Note, error) { return s.store.Get(ctx, id) }
func (s *Service) List(ctx context.Context) ([]Note, error)         { return s.store.List(ctx) }
func (s *Service) Delete(ctx context.Context, id string) error      { return s.store.Delete(ctx, id) }

func newID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
