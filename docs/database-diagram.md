# Conetza — Diagrama de Base de Datos (ERD)

```mermaid
erDiagram
    users {
        uuid id PK
        string email
        timestamp created_at
    }

    profiles {
        uuid id PK
        uuid user_id FK
        string username
        string display_name
        text bio
        string avatar_url
        string category
        string[] tags
        string location
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    social_accounts {
        uuid id PK
        uuid profile_id FK
        string platform
        string handle
        string profile_url
        integer followers_count
        string access_token
        string refresh_token
        timestamp token_expires_at
        boolean is_primary
        timestamp created_at
    }

    swipes {
        uuid id PK
        uuid swiper_id FK
        uuid swiped_id FK
        string direction
        timestamp created_at
    }

    matches {
        uuid id PK
        uuid profile_a_id FK
        uuid profile_b_id FK
        string status
        timestamp matched_at
        timestamp updated_at
    }

    messages {
        uuid id PK
        uuid match_id FK
        uuid sender_id FK
        text content
        string message_type
        boolean is_read
        timestamp created_at
    }

    notifications {
        uuid id PK
        uuid profile_id FK
        string type
        jsonb payload
        boolean is_read
        timestamp created_at
    }

    users ||--|| profiles : "tiene"
    profiles ||--o{ social_accounts : "tiene"
    profiles ||--o{ swipes : "swiper_id"
    profiles ||--o{ swipes : "swiped_id"
    profiles ||--o{ matches : "profile_a_id"
    profiles ||--o{ matches : "profile_b_id"
    matches ||--o{ messages : "pertenece a"
    profiles ||--o{ messages : "sender_id"
    profiles ||--o{ notifications : "recibe"
```

## Descripción de tablas

### `users`
Tabla nativa de Supabase Auth. Se extiende con `profiles`.

### `profiles`
Perfil público del creador de contenido.
- `category`: gaming, lifestyle, tech, fitness, music, etc.
- `tags`: arreglo de etiquetas del nicho (e.g. ["fps", "español", "tutorial"])

### `social_accounts`
Redes sociales vinculadas al perfil.
- `platform`: `twitch` | `instagram` | `tiktok` | `youtube` | `twitter`
- `is_primary`: la red con la que inició sesión (OAuth principal)

### `swipes`
Registro de cada swipe.
- `direction`: `like` | `pass`
- Índice único en `(swiper_id, swiped_id)` para evitar duplicados

### `matches`
Se crea cuando dos perfiles se dan like mutuamente.
- `status`: `active` | `unmatched`
- Índice único en `(profile_a_id, profile_b_id)` donde `profile_a_id < profile_b_id`

### `messages`
Mensajes dentro de un match.
- `message_type`: `text` | `image` | `link`

### `notifications`
Notificaciones in-app.
- `type`: `new_match` | `new_message` | `new_like`
- `payload`: datos extra en JSON (e.g. `{ "match_id": "...", "from": "username" }`)
