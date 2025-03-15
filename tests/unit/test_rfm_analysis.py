# RFM Insights - Unit Tests for RFM Analysis Module

import unittest
import pandas as pd
import numpy as np
import datetime
from backend.rfm_analysis import RFMAnalysis

class TestRFMAnalysis(unittest.TestCase):
    
    def setUp(self):
        """Set up test data for RFM analysis"""
        # Create sample data for testing
        self.test_data = pd.DataFrame({
            'customer_id': ['C001', 'C002', 'C003', 'C004', 'C005'],
            'last_purchase_date': [
                datetime.datetime.now() - datetime.timedelta(days=5),
                datetime.datetime.now() - datetime.timedelta(days=20),
                datetime.datetime.now() - datetime.timedelta(days=60),
                datetime.datetime.now() - datetime.timedelta(days=100),
                datetime.datetime.now() - datetime.timedelta(days=150)
            ],
            'purchase_count': [20, 10, 5, 3, 1],
            'total_spent': [5000, 2500, 1000, 500, 100]
        })
        
        # Initialize RFM Analysis object
        self.rfm = RFMAnalysis(
            data=self.test_data,
            user_id_col='customer_id',
            recency_col='last_purchase_date',
            frequency_col='purchase_count',
            monetary_col='total_spent',
            segment_type='ecommerce'
        )
    
    def test_preprocess_data(self):
        """Test data preprocessing functionality"""
        processed_data = self.rfm.preprocess_data()
        
        # Check if processed data has the expected columns
        self.assertIn('recency_days', processed_data.columns)
        self.assertEqual(len(processed_data), 5)  # Should have 5 rows
        
        # Check if recency days are calculated correctly
        self.assertTrue(all(processed_data['recency_days'] >= 0))
    
    def test_calculate_rfm_scores(self):
        """Test RFM score calculation"""
        rfm_data = self.rfm.calculate_rfm_scores()
        
        # Check if RFM scores are calculated
        self.assertIn('r_score', rfm_data.columns)
        self.assertIn('f_score', rfm_data.columns)
        self.assertIn('m_score', rfm_data.columns)
        self.assertIn('rfm_score', rfm_data.columns)
        
        # Check if scores are within expected range
        self.assertTrue(all(1 <= rfm_data['r_score']) and all(rfm_data['r_score'] <= 4))
        self.assertTrue(all(1 <= rfm_data['f_score']) and all(rfm_data['f_score'] <= 4))
        self.assertTrue(all(1 <= rfm_data['m_score']) and all(rfm_data['m_score'] <= 4))
    
    def test_segment_customers(self):
        """Test customer segmentation"""
        segments = self.rfm.segment_customers()
        
        # Check if segmentation is performed
        self.assertIn('segment', segments.columns)
        
        # Check if all customers are assigned a segment
        self.assertEqual(len(segments['segment'].unique()), len(segments['segment'].dropna().unique()))
        
        # Check if segments match expected types
        expected_segments = [
            "Campeões", "Clientes Fiéis", "Fiéis em Potencial", "Novos Clientes",
            "Clientes Promissores", "Clientes que Precisam de Atenção", 
            "Clientes Quase Dormentes", "Clientes que Não Posso Perder",
            "Clientes em Risco", "Clientes Hibernando", "Clientes Perdidos", "Outros"
        ]
        
        for segment in segments['segment'].unique():
            self.assertIn(segment, expected_segments)

if __name__ == '__main__':
    unittest.main()