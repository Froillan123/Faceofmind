from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import CommunityComment, CommunityPost, User
from schemas import CommunityCommentCreate, CommunityCommentResponse
from dependencies import get_current_user

router = APIRouter(prefix="/posts", tags=["comments"])

@router.get("/{post_id}/comments", response_model=List[CommunityCommentResponse])
def get_comments(post_id: int, db: Session = Depends(get_db)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    return db.query(CommunityComment).filter(CommunityComment.post_id == post_id).all()

@router.post("/{post_id}/comments", response_model=CommunityCommentResponse)
def add_comment(post_id: int, comment: CommunityCommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    db_comment = CommunityComment(post_id=post_id, user_id=current_user.id, **comment.dict())
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)
    return db_comment 