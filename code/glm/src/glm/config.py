import os
import json

# write a BIDS stats model in json format
class ModelConfig:
    """
    Parse the model parameters for 1st-level GLM

    Inputs:
        filename - Full path to the model config json file. If filename is
                   not set, it will check the environment variable MODEL_CONFIG.
                   The default configuration file is located in the config directory.
    """

    def __init__(
        self,
        filename=None,
        **kwargs
    ):
        
        if not filename:
            try:
                filename = os.environ["MODEL_CONFIG"]
            except KeyError:
                raise ValueError("No default config found in environment variable")
        self._load_json(filename)

        # Override any values using kwargs if necessary
        for key, value in kwargs.items():
            setattr(self, key, value)

    def _load_json(self, filename):
        """
        Load configuration from a JSON file and update instance attributes
        """
        import json
        if not os.path.isfile(filename):
            raise ValueError(
                f"Configuration file {filename} not found. Try again"
            )
        with open(filename, "r") as f:
            config_data = json.load(f)

        # Update the instance attributes with values from the JSON
        for key, value in config_data.items():
            setattr(self, key, value)
                
    def __repr__(self):
        # Detailed string for debugging or logging
        return f"ModelConfig({', '.join(f'{key}={value!r}' for key, value in self.__dict__.items())})"
