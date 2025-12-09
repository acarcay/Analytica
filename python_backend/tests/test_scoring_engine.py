"""
Scoring Engine Tests

Tests for the MP scoring engine module.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class TestScoringFormula:
    """Tests for the scoring formula calculation."""
    
    def test_score_with_all_metrics(self):
        """Score = (T × 5) + (S × 2) + (G × 10) + (H × 1)."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            
            # T=5, S=10, G=2, H=7.5
            # (5×5) + (10×2) + (2×10) + (7.5×1) = 25 + 20 + 20 + 7.5 = 72.5
            score = engine.calculate_score(
                law_proposals=5, 
                written_questions=10,
                speeches=2,
                news_impact_avg=7.5
            )
            assert score == 72.5

    def test_score_with_zero_proposals(self):
        """Score should work with zero law proposals."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            
            # T=0, S=0, G=0, H=5.0 = 5.0
            score = engine.calculate_score(law_proposals=0, news_impact_avg=5.0)
            assert score == 5.0

    def test_score_with_zero_impact(self):
        """Score should work with zero news impact."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            
            # T=3, S=0, G=0, H=0 = 3*5 = 15.0
            score = engine.calculate_score(law_proposals=3, news_impact_avg=0.0)
            assert score == 15.0

    def test_score_rounding(self):
        """Score should be rounded to 2 decimal places."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            
            # T=2, S=0, G=0, H=3.333 = 2*5 + 3.333 = 13.33
            score = engine.calculate_score(law_proposals=2, news_impact_avg=3.333)
            assert score == 13.33

    def test_high_performer_score(self):
        """High performer with many proposals, questions, speeches and good impact."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            
            # T=10, S=50, G=20, H=9.5
            # (10*5) + (50*2) + (20*10) + (9.5*1) = 50 + 100 + 200 + 9.5 = 359.5
            score = engine.calculate_score(
                law_proposals=10, 
                written_questions=50,
                speeches=20,
                news_impact_avg=9.5
            )
            assert score == 359.5


class TestScoringWeights:
    """Tests for scoring weight constants."""
    
    def test_law_proposal_weight(self):
        """Law proposal weight should be 5 (reduced from 10)."""
        from services.scoring_engine import ScoringEngine
        assert ScoringEngine.LAW_PROPOSAL_WEIGHT == 5.0

    def test_question_weight(self):
        """Question weight should be 2."""
        from services.scoring_engine import ScoringEngine
        assert ScoringEngine.QUESTION_WEIGHT == 2.0

    def test_speech_weight(self):
        """Speech weight should be 10."""
        from services.scoring_engine import ScoringEngine
        assert ScoringEngine.SPEECH_WEIGHT == 10.0

    def test_news_impact_weight(self):
        """News impact weight should be 1."""
        from services.scoring_engine import ScoringEngine
        assert ScoringEngine.NEWS_IMPACT_WEIGHT == 1.0


class TestScoringResult:
    """Tests for ScoringResult dataclass."""
    
    def test_scoring_result_creation(self):
        """Should create ScoringResult with all fields."""
        from services.scoring_engine import ScoringResult
        
        result = ScoringResult(
            mp_id="mp_001",
            mp_name="Test Vekil",
            old_score=10.0,
            new_score=55.0,
            law_bonus=25.0,
            question_bonus=20.0,
            speech_bonus=5.0,
            news_impact=5.0,
            news_count=3,
            is_passive=False,
            success=True
        )
        
        assert result.mp_id == "mp_001"
        assert result.mp_name == "Test Vekil"
        assert result.old_score == 10.0
        assert result.new_score == 55.0
        assert result.law_bonus == 25.0
        assert result.question_bonus == 20.0
        assert result.speech_bonus == 5.0
        assert result.news_impact == 5.0
        assert result.news_count == 3
        assert result.is_passive is False
        assert result.success is True
        assert result.error_message is None

    def test_scoring_result_with_error(self):
        """Should create ScoringResult with error message."""
        from services.scoring_engine import ScoringResult
        
        result = ScoringResult(
            mp_id="mp_002",
            mp_name="Error Vekil",
            old_score=5.0,
            new_score=5.0,
            law_bonus=0,
            question_bonus=0,
            speech_bonus=0,
            news_impact=0,
            news_count=0,
            is_passive=True,
            success=False,
            error_message="API connection failed"
        )
        
        assert result.success is False
        assert result.error_message == "API connection failed"
        assert result.is_passive is True


class TestDryRunMode:
    """Tests for dry-run mode."""
    
    def test_dry_run_flag(self):
        """Dry run mode should be stored."""
        from services.scoring_engine import ScoringEngine
        
        with patch('services.scoring_engine.get_firestore_service'), \
             patch('services.scoring_engine.get_news_scraper'), \
             patch('services.scoring_engine.get_gemini_analyzer'):
            
            engine = ScoringEngine(dry_run=True)
            assert engine.dry_run is True
            
            engine2 = ScoringEngine(dry_run=False)
            assert engine2.dry_run is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
