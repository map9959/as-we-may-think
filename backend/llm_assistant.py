from llama_cpp import Llama
from sentence_transformers import SentenceTransformer
import faiss
import os
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
import logging
import re

logger = logging.getLogger(__name__)

class LLMAssistant:
    def __init__(self, 
                 model_path: Optional[str] = None, 
                 embedding_model: str = "all-MiniLM-L6-v2"):
        """
        Initialize the LLM Assistant.
        
        Args:
            model_path: Path to the GGUF model file. If None, it will try to use a default model.
            embedding_model: The sentence transformer model to use for embeddings.
        """
        self.model_path = model_path
        self.model = None
        self.embedding_model = SentenceTransformer(embedding_model)
        self.index = None
        self.documents = []
        
        # Load the model if specified
        if self.model_path and os.path.exists(self.model_path):
            self._load_model()
    
    def _get_model_params(self, model_path: str) -> Dict[str, Any]:
        """
        Determine appropriate model parameters based on the filename.
        
        Args:
            model_path: Path to the model file
            
        Returns:
            Dictionary of model parameters
        """
        filename = os.path.basename(model_path).lower()
        
        # Default parameters
        params = {
            "n_ctx": 2048,  # Default context size
            "n_threads": 4,  # Default number of threads
            "n_gpu_layers": 0  # Default to CPU only
        }
        
        # Model-specific adjustments
        if any(name in filename for name in ['llama', 'meta-llama']):
            if "3" in filename:  # Llama 3 models
                params["n_ctx"] = 4096
            elif "2" in filename:  # Llama 2 models
                params["n_ctx"] = 4096
        elif 'mistral' in filename:
            params["n_ctx"] = 4096
        elif 'phi' in filename:
            if "mini" in filename:  # phi-mini models
                params["n_ctx"] = 4096
            else:
                params["n_ctx"] = 2048
        elif 'gemma' in filename:
            params["n_ctx"] = 4096
        
        # Check for quantization level to optimize parameters
        if "q4_0" in filename or "q4_k_m" in filename:
            params["n_batch"] = 512  # Use larger batch for more efficient 4-bit quantized models
            
        return params
    
    def _load_model(self) -> Tuple[bool, str]:
        """
        Load the LLM model.
        
        Returns:
            Tuple of (success, error_message)
        """
        if not self.model_path or not os.path.exists(self.model_path):
            return False, f"Model path '{self.model_path}' does not exist"
            
        try:
            logger.info(f"Loading model from {self.model_path}")
            
            # Get model parameters based on the filename
            params = self._get_model_params(self.model_path)
            logger.info(f"Using model parameters: {params}")
            
            # Initialize the model with llama-cpp-python
            self.model = Llama(
                model_path=self.model_path,
                **params
            )
            
            logger.info("Model loaded successfully")
            return True, ""
        except Exception as e:
            error_msg = f"Error loading model: {e}"
            logger.error(error_msg)
            
            # If the initial parameters failed, try with minimal parameters
            try:
                logger.info(f"Retrying with minimal parameters")
                self.model = Llama(
                    model_path=self.model_path,
                    n_ctx=2048,
                    n_threads=1
                )
                logger.info("Model loaded successfully with minimal parameters")
                return True, ""
            except Exception as e2:
                logger.error(f"Error loading model with minimal parameters: {e2}")
            
            # If both attempts failed, model could not be loaded
            return False, error_msg
    
    def set_model_path(self, model_path: str):
        """Set the model path and try to load the model."""
        self.model_path = model_path
        success, error_msg = self._load_model()
        return success, error_msg
    
    def index_documents(self, documents: List[Dict[str, Any]]):
        """
        Create a searchable index from a list of documents.
        
        Args:
            documents: List of document dictionaries with 'title', 'content' and other fields
        """
        self.documents = documents
        
        # Extract texts to embed
        texts = [f"{doc.get('title', '')}\n{doc.get('content', '')}" for doc in documents]
        
        # Generate embeddings
        embeddings = self.embedding_model.encode(texts)
        
        # Create and populate FAISS index
        dimension = embeddings.shape[1]
        self.index = faiss.IndexFlatL2(dimension)
        self.index.add(np.array(embeddings).astype('float32'))
        
        return len(documents)
    
    def search_documents(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Search for relevant documents based on the query.
        
        Args:
            query: The search query
            top_k: Number of results to return
            
        Returns:
            List of relevant documents
        """
        if not self.index or not self.documents:
            return []
        
        # Encode the query
        query_vector = self.embedding_model.encode([query])
        
        # Search the index
        distances, indices = self.index.search(np.array(query_vector).astype('float32'), top_k)
        
        # Return the matched documents
        results = []
        for idx in indices[0]:
            if idx < len(self.documents):
                results.append(self.documents[idx])
        
        return results
    
    def generate_response(self, prompt: str, max_tokens: int = 64) -> str:
        """
        Generate a response using the LLM.
        
        Args:
            prompt: The input prompt
            max_tokens: Maximum number of tokens to generate
            
        Returns:
            Generated text response
        """
        if not self.model:
            return "Model not loaded. Please set a valid model path first."
        
        try:
            # Generate response with llama-cpp-python
            response = self.model(
                prompt,
                max_tokens=max_tokens,
                temperature=0.7,
                repeat_penalty=1.1,
                echo=False  # Don't echo the prompt in the response
            )
            
            # Extract the generated text from the response object
            generated_text = response["choices"][0]["text"]
            return generated_text
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            return f"Error generating response: {str(e)}"
    
    def answer_with_context(self, query: str, max_tokens: int = 64) -> Dict[str, Any]:
        """
        Answer a question with relevant context from indexed documents.
        
        Args:
            query: The question to answer
            max_tokens: Maximum number of tokens in the response
            
        Returns:
            Dictionary with generated answer and supporting documents
        """
        # Search for relevant context
        relevant_docs = self.search_documents(query, top_k=3)
        
        # Create context string from relevant documents
        context = ""
        for i, doc in enumerate(relevant_docs):
            context += f"Document {i+1}:\nTitle: {doc.get('title', 'Untitled')}\n"
            context += f"Content: {doc.get('content', '')}\n\n"
        
        # Create the prompt with context
        prompt = f"""<|system|>You are the Memex, a helpful assistant that answers queries in brief summaries.<|end|>
        <|user|>Based on the following information:

{context}

Answer this question: {query}<|end|>

<|assistant|>Answer:"""
        
        # Generate response
        answer = self.generate_response(prompt, max_tokens)
        
        return {
            "answer": answer,
            "sources": relevant_docs
        }