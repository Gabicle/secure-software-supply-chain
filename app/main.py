from fastapi import FastAPI

app = FastAPI(title="Secure Supply Chain API")


@app.get("/health")
def health():
    return {"status": "healthy"}