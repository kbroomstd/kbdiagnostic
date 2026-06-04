package main

type Server struct {
	port int
	db   *sql.DB
}

func (s *Server) HealthCheck() error {
	if s.db == nil {
		return fmt.Errorf("database not connected")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := s.db.PingContext(ctx); err != nil {
		return fmt.Errorf("health ping failed: %w", err)
	}
	return nil
}
