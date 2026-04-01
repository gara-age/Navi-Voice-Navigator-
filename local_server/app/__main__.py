import uvicorn


def main() -> None:
    uvicorn.run("local_server.app.main:app", host="127.0.0.1", port=18400, reload=True)


if __name__ == "__main__":
    main()
