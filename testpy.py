import socket
import json
import time

def test_socket():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        # Connect to the server
        sock.connect(('127.0.0.1', 5000))
        print("Connected to server")

        # Send command list
        sock.sendall("COMMAND_LIST;help;move;attack".encode())
        print("Sent command list")

        # Create a test state
        test_state = {
            "bots": [
                {"id": 1, "role": "fighter", "subrole": "melee", "health": 100},
                {"id": 2, "role": "healer", "subrole": "support", "health": 80}
            ],
            "time_left": 120
        }

        # Send state as JSON
        sock.sendall(json.dumps(test_state).encode())
        print("Sent test state")

        # Try to receive response
        response = sock.recv(1024).decode()
        print(f"Received response: {response}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()
        print("Connection closed")

if __name__ == "__main__":
    test_socket()
