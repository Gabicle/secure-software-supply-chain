from contextlib import asynccontextmanager

from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import SessionLocal, engine
from models import Base, Item


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Secure Supply Chain API",
    lifespan=lifespan,
)


class ItemCreate(BaseModel):
    name: str


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.post("/items")
def create_item(item: ItemCreate):
    db: Session = SessionLocal()

    try:
        new_item = Item(name=item.name)
        db.add(new_item)
        db.commit()
        db.refresh(new_item)

        return {
            "id": new_item.id,
            "name": new_item.name,
        }
    finally:
        db.close()


@app.get("/items")
def get_items():
    db: Session = SessionLocal()

    try:
        items = db.query(Item).all()

        return [
            {
                "id": item.id,
                "name": item.name,
            }
            for item in items
        ]
    finally:
        db.close()