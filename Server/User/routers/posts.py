from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import CommunityPost, User, CommunityComment
from schemas import CommunityPostCreate, CommunityPostUpdate, CommunityPostResponse
from dependencies import get_current_user
from sqlalchemy import func

router = APIRouter(prefix="/posts", tags=["posts"])

@router.get("/", response_model=List[CommunityPostResponse])
def get_posts(db: Session = Depends(get_db)):
    posts = db.query(CommunityPost).order_by(CommunityPost.id.desc()).all()
    result = []
    for post in posts:
        comment_count = db.query(func.count(CommunityComment.id)).filter(CommunityComment.post_id == post.id).scalar()
        post_dict = post.__dict__.copy()
        post_dict['comment_count'] = comment_count
        result.append(CommunityPostResponse(**post_dict))
    return result

@router.get("/{post_id}", response_model=CommunityPostResponse)
def get_post(post_id: int, db: Session = Depends(get_db)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    comment_count = db.query(func.count(CommunityComment.id)).filter(CommunityComment.post_id == post.id).scalar()
    post_dict = post.__dict__.copy()
    post_dict['comment_count'] = comment_count
    return CommunityPostResponse(**post_dict)

@router.post("/", response_model=CommunityPostResponse)
def create_post(post: CommunityPostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post_data = {k: v for k, v in post.dict().items() if v is not None}
    db_post = CommunityPost(user_id=current_user.id, **post_data)
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    post_dict = db_post.__dict__.copy()
    post_dict['comment_count'] = 0
    return CommunityPostResponse(**post_dict)

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