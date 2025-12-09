"""
Static MP Loader Tests

Tests for the static MP data loader module.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import patch, mock_open
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.static_mp_loader import (
    StaticMP,
    load_all_mps,
    load_mps_by_city,
    load_mps_by_party,
    get_party_distribution,
    search_mp,
)


class TestStaticMP:
    """Tests for StaticMP dataclass."""
    
    def test_id_generation(self):
        """ID should be generated from normalized name with hash."""
        mp = StaticMP(name="Ahmet Yılmaz", party="AKP", city="İstanbul")
        
        assert mp.id.startswith("mv_")
        assert "ahmet" in mp.id.lower()
        assert len(mp.id) > 10  # Should have hash suffix

    def test_id_uniqueness(self):
        """Different names should generate different IDs."""
        mp1 = StaticMP(name="Ahmet Yılmaz", party="AKP", city="İstanbul")
        mp2 = StaticMP(name="Mehmet Yılmaz", party="AKP", city="İstanbul")
        
        assert mp1.id != mp2.id

    def test_normalized_party_akp(self):
        """AK Parti should normalize to AKP."""
        mp = StaticMP(name="Test", party="AK Parti", city="Ankara")
        assert mp.normalized_party == "AKP"

    def test_normalized_party_chp(self):
        """CHP should stay as CHP."""
        mp = StaticMP(name="Test", party="CHP", city="Ankara")
        assert mp.normalized_party == "CHP"

    def test_normalized_party_iyi(self):
        """İYİ Parti should normalize to İYİ."""
        mp = StaticMP(name="Test", party="İYİ Parti", city="Ankara")
        assert mp.normalized_party == "İYİ"

    def test_normalized_party_dem(self):
        """DEM PARTİ should normalize to DEM."""
        mp = StaticMP(name="Test", party="DEM PARTİ", city="Diyarbakır")
        assert mp.normalized_party == "DEM"

    def test_normalized_party_unknown(self):
        """Unknown party should return original."""
        mp = StaticMP(name="Test", party="BİLİNMEYEN", city="Ankara")
        assert mp.normalized_party == "BİLİNMEYEN"


class TestLoadAllMps:
    """Tests for load_all_mps function."""
    
    def test_returns_list(self):
        """Should return a list of StaticMP objects."""
        mps = load_all_mps()
        
        assert isinstance(mps, list)
        if mps:  # If data exists
            assert all(isinstance(mp, StaticMP) for mp in mps)

    def test_expected_count(self):
        """Should load approximately 600 MPs."""
        mps = load_all_mps()
        
        # Allow some variance, but should be around 600
        assert 500 <= len(mps) <= 650

    def test_mps_have_required_fields(self):
        """Each MP should have name, party, and city."""
        mps = load_all_mps()
        
        for mp in mps[:10]:  # Check first 10
            assert mp.name
            assert mp.party
            assert mp.city


class TestLoadMpsByCity:
    """Tests for load_mps_by_city function."""
    
    def test_returns_dict(self):
        """Should return a dictionary."""
        result = load_mps_by_city()
        assert isinstance(result, dict)

    def test_has_major_cities(self):
        """Should include major cities."""
        result = load_mps_by_city()
        
        # Check that result has multiple cities (81 expected)
        assert len(result) >= 70  # Allow some variance
        
        # Check for at least some major cities (may have different casing)
        city_keys_lower = [k.lower() for k in result.keys()]
        assert any('istanbul' in k.lower() or 'i̇stanbul' in k.lower() for k in result.keys())
        assert any('ankara' in k.lower() for k in result.keys())


    def test_city_values_are_lists(self):
        """Each city should have a list of MPs."""
        result = load_mps_by_city()
        
        for city, mps in result.items():
            assert isinstance(mps, list)
            if mps:
                assert all(isinstance(mp, StaticMP) for mp in mps)


class TestLoadMpsByParty:
    """Tests for load_mps_by_party function."""
    
    def test_returns_dict(self):
        """Should return a dictionary."""
        result = load_mps_by_party()
        assert isinstance(result, dict)

    def test_has_major_parties(self):
        """Should include major parties."""
        result = load_mps_by_party()
        
        assert "AKP" in result
        assert "CHP" in result
        assert "MHP" in result

    def test_akp_has_most_mps(self):
        """AKP should have the most MPs (majority party)."""
        result = load_mps_by_party()
        
        if "AKP" in result:
            akp_count = len(result["AKP"])
            for party, mps in result.items():
                if party != "AKP":
                    assert akp_count >= len(mps), f"AKP should have more MPs than {party}"


class TestGetPartyDistribution:
    """Tests for get_party_distribution function."""
    
    def test_returns_dict(self):
        """Should return a dictionary."""
        result = get_party_distribution()
        assert isinstance(result, dict)

    def test_values_are_integers(self):
        """Party counts should be integers."""
        result = get_party_distribution()
        
        for party, count in result.items():
            assert isinstance(count, int)
            assert count > 0

    def test_total_approximately_600(self):
        """Total should be approximately 600."""
        result = get_party_distribution()
        total = sum(result.values())
        
        assert 500 <= total <= 650


class TestSearchMp:
    """Tests for search_mp function."""
    
    def test_finds_existing_mp(self):
        """Should find MPs by name."""
        # Load all to get a real name
        all_mps = load_all_mps()
        if all_mps:
            first_mp = all_mps[0]
            name_part = first_mp.name.split()[0]  # First name
            
            results = search_mp(name_part)
            assert len(results) >= 1

    def test_case_insensitive(self):
        """Search should be case insensitive."""
        results_lower = search_mp("ahmet")
        results_upper = search_mp("AHMET")
        
        # Both should find the same MPs
        assert len(results_lower) == len(results_upper)

    def test_returns_empty_for_nonexistent(self):
        """Should return empty list for non-existent name."""
        results = search_mp("XyzNoSuchName123")
        assert results == []

    def test_partial_match(self):
        """Should find MPs with partial name match."""
        results = search_mp("ÖZTÜRK")  # Common surname
        
        # Should find multiple MPs with this surname
        assert len(results) >= 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
