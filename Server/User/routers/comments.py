from fastapi import APIRouter, Depends, HTTPException, status, Path
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
    return db.query(CommunityComment).filter(CommunityComment.post_id == post_id).order_by(CommunityComment.id.desc()).all()

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

@router.put("/{post_id}/comments/{comment_id}", response_model=CommunityCommentResponse)
def edit_comment(post_id: int, comment_id: int, comment_update: CommunityCommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_comment = db.query(CommunityComment).filter(CommunityComment.id == comment_id, CommunityComment.post_id == post_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    db_comment.content = comment_update.content
    db.commit()
    db.refresh(db_comment)
    return db_comment

@router.delete("/{post_id}/comments/{comment_id}")
def delete_comment(post_id: int, comment_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_comment = db.query(CommunityComment).filter(CommunityComment.id == comment_id, CommunityComment.post_id == post_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not enough permissions")
    db.delete(db_comment)
    db.commit()
    return {"message": "Comment deleted successfully"} 