from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import CommunityPost, User
from schemas import CommunityPostCreate, CommunityPostUpdate, CommunityPostResponse
from dependencies import get_current_user

router = APIRouter(prefix="/posts", tags=["posts"])

@router.get("/", response_model=List[CommunityPostResponse])
def get_posts(db: Session = Depends(get_db)):
    return db.query(CommunityPost).all()

@router.get("/{post_id}", response_model=CommunityPostResponse)
def get_post(post_id: int, db: Session = Depends(get_db)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    return post

@router.post("/", response_model=CommunityPostResponse)
def create_post(post: CommunityPostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_post = CommunityPost(user_id=current_user.id, **post.dict())
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return db_post

@router.put("/{post_id}", response_model=CommunityPostResponse)
def update_post(post_id: int, post_update: CommunityPostUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    post.content = post_update.content
    db.commit()
    db.refresh(post)
    return post

@router.delete("/{post_id}")
def delete_post(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    db.delete(post)
    db.commit()
    return {"message": "Post deleted successfully"} 