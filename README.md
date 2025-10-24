# 🌐 Collaborative Canvas: A Real-Time Whiteboard Platform

## 🎯 Project Overview

**Collaborative Canvas** is a high-performance, real-time application designed to facilitate seamless collaboration across distributed teams. It provides a shared digital workspace where users can create, annotate, and brainstorm interactively, with all changes instantly synchronized across all active participants.

The architecture is built on a **WebSocket-driven** backend to ensure low-latency communication, supporting a rich, feature-complete frontend editing experience.

---

## ✨ Core Features

### Frontend Capabilities (User Experience)

The client application focuses on providing a powerful, intuitive creation and editing environment:

| Category | Features |
| :--- | :--- |
| **Creation Tools** | Drawing of standard shapes (**Rectangle, Circle, Arrow, Line**), **Pencil** drawing with configurable color, stroke width, and opacity. |
| **Editing & Content** | **Eraser** (stroke-based removal), **Image Insertion**, and rich **Text Insertion** with formatting options. |
| **Interaction** | **Panning Tool** (Hand Tool) for seamless board navigation, and a robust **Selection Tool** for object manipulation. |
| **Customization** | Comprehensive **Background Selection** (solid color or pattern). |
| **Persistence & Sync** | **Real-time Autosave** to the backend via WebSockets, **Live Collaboration** for instant UI updates from other users, and **Document Download** functionality. |

### Backend Capabilities (System Services)

The server ensures secure access, reliable document storage, and efficient real-time synchronization:

| Service | Functionality |
| :--- | :--- |
| **Authentication** | Secure **User Registration** and **Login** (Email-based). |
| **Data Persistence** | Robust storage and efficient retrieval of complex document states from the database. |
| **Real-Time Engine** | Accepts and processes live document changes from the frontend, persists updates, and broadcasts necessary diffs to all collaborating clients. |

---

## 🏗️ Technical Architecture Overview

The system employs a clear separation of concerns, utilizing a modern **micro-service pattern** centered around a dedicated real-time layer:

1.  **Client Application:** Renders the canvas and handles user input. It sends state mutation requests to the real-time server.
2.  **Real-Time Server (WebSockets):** The communication hub. It receives granular operations (e.g., "move object X"), authenticates the request, and forwards the operation to the Persistence/API layer. It then broadcasts the successful operation to all connected clients for immediate rendering.
3.  **API & Persistence Layer:** Handles traditional REST operations (registration, document listing, download) and is responsible for safely committing the final document state to the database.

This architecture ensures that the **data stream for collaboration is decoupled** from slower API traffic, maximizing responsiveness.

---

## 🛠️ Technology Stack (Planned)

| Component | Preferred Technologies | Rationale |
| :--- | :--- | :--- |
| **Frontend** | React or Vue.js, Konva.js / Fabric.js (Canvas), WebSockets Client | Modern framework for component-based UI, specialized library for high-performance canvas rendering. |
| **Backend** | Node.js (with Express/NestJS), Socket.IO / ws library | Excellent for high-concurrency, non-blocking I/O, ideal for WebSocket and real-time operations. |
| **Database** | PostgreSQL (Relational) or MongoDB (Document Store) | PostgreSQL with JSONB for structured flexibility, or MongoDB for native JSON document handling. |
| **Authentication** | JWT (JSON Web Tokens) | Stateless, secure, and scalable method for user session management. |

---

## 📁 Document State Structure

The application's core data is represented as a structured JSON object, allowing for efficient serialization, persistence, and diffing.

The root object contains slides, which, in turn, hold an array of all distinct objects and their attributes:

```json
{
  "slide_uuid_1": {
    "id": "slide_uuid_1",
    "objects": [
      {
        "id": "obj_rect_001",
        "type": "rectangle",
        "attributes": { /* ... */ }
      },
      { /* ... other objects (circle, text, image, etc.) */ }
    ]
  }
}