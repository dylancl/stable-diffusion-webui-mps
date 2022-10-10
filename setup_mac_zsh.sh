#!/usr/bin/env zsh -l

if ! command -v conda &> /dev/null
then
    echo "conda is not installed. Installing miniconda"

    # Install conda
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh

    # Install conda
    bash Miniconda3-latest-MacOSX-arm64.sh -b -p $HOME/miniconda
    
    # Add conda to path
    export PATH="$HOME/miniconda/bin:$PATH"

else
    echo "conda is installed."

fi

# Initialize conda
conda init zsh

# Remove previous conda environment
conda remove -n web-ui --all

# Create conda environment
conda create -n web-ui python=3.10

# Activate conda environment
conda activate web-ui

# Remove previous git repository
rm -rf stable-diffusion-webui

# Clone the repo
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git

# Enter the repo
cd stable-diffusion-webui

echo "============================================="
echo "============================================="
echo "===========STABLE DIFFUSION MODEL============"
echo "============================================="
echo "============================================="

# Prompt the user to ask if they've already installed the model
echo "If you've already downloaded the model, you now have time to copy it yourself to stable-diffusion-webui/models/Stable-diffusion/"
echo "If you haven't downloaded the model yet, you can enter n to downloaded the model from hugging face."
while true; do
    read "yn?Have you already installed the model? (y/n) "
    case $yn in
        [Yy]* ) echo "Skipping model installation"; break;;
        [Nn]* ) echo "Installing model"; 
        # Prompt the user for their hugging face token and store it in a variable
        echo "Register an account on huggingface.co and then create a token (read) on https://huggingface.co/settings/tokens"
        echo "Also make sure to accept the disclaimer here: https://huggingface.co/CompVis/stable-diffusion-v-1-4-original"
        read "hf_token?Please enter your hugging face token: " 
        # Install the model
        headertoken="Authorization: Bearer $hf_token"
        curl -L -H "$headertoken" -o models/Stable-diffusion/sd-v1-4.ckpt https://huggingface.co/CompVis/stable-diffusion-v-1-4-original/resolve/main/sd-v1-4.ckpt 
        break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Clone required repos
git clone https://github.com/CompVis/stable-diffusion.git repositories/stable-diffusion
 
git clone https://github.com/CompVis/taming-transformers.git repositories/taming-transformers

git clone https://github.com/sczhou/CodeFormer.git repositories/CodeFormer
    
git clone https://github.com/salesforce/BLIP.git repositories/BLIP

git clone https://github.com/Birch-san/k-diffusion repositories/k-diffusion

# Before we continue, check if 1) the model is in place 2) the repos are cloned
if ( [ -f "models/sd-v1-4.ckpt" ] || [ -f "models/Stable-diffusion/sd-v1-4.ckpt" ] ) && [ -d "repositories/stable-diffusion" ] && [ -d "repositories/taming-transformers" ] && [ -d "repositories/CodeFormer" ] && [ -d "repositories/BLIP" ]; then
    echo "All files are in place. Continuing installation."
else
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "The check for the models & required repositories has failed."
    echo "Please check if the model is in place and the repos are cloned."
    echo "You can find the model in stable-diffusion-webui/models/Stable-diffusion/sd-v1-4.ckpt"
    echo "You can find the repos in stable-diffusion-webui/repositories/"
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    exit 1
fi

# Install dependencies

# In order for the requirements.txt packages to install correctly, functorch needs to be installed already.
# functorch will not successfully build without torch, but also won't build under the nightly build we use.
pip install torch==1.12.1
pip install git+https://github.com/pytorch/functorch@a6e0e61242d2ed10287965c3febc426fd6abf5f9

pip install -r requirements.txt

pip install git+https://github.com/openai/CLIP.git@d50d76daa670286dd6cacf3bcd80b5e4823fc8e1

pip install git+https://github.com/TencentARC/GFPGAN.git@8d2447a2d918f8eba5a4a01463fd48e45126a379

# Remove torch and all related packages
pip uninstall torch torchvision torchaudio -y

# Normally, we would install the latest nightly build of PyTorch here,
# But there's currently a performance regression in the latest nightly releases.
# Therefore, we're going to use this old version which doesn't have it.
# TODO: go back once fixed on PyTorch side
pip install --pre torch==1.13.0.dev20220922 torchvision==0.14.0.dev20220924 -f https://download.pytorch.org/whl/nightly/cpu/torch_nightly.html --no-deps

# Missing dependencie(s)
pip install gdown fastapi

# Activate the MPS_FALLBACK conda environment variable
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1

# We need to reactivate the conda environment for the variable to take effect
conda deactivate
conda activate web-ui

# Check if the config var is set
if [ -z "$PYTORCH_ENABLE_MPS_FALLBACK" ]; then
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    echo "The PYTORCH_ENABLE_MPS_FALLBACK variable is not set."
    echo "This means that the script will either fall back to CPU or fail."
    echo "To fix this, please run the following command:"
    echo "conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1"
    echo "Or, try running the script again."
    echo "============================================="
    echo "====================ERROR===================="
    echo "============================================="
    exit 1
fi

# Create a shell script to run the web ui
echo "#!/usr/bin/env bash -l
# This should not be needed since it's configured during installation, but might as well have it here.
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1
# Activate conda environment
conda activate web-ui
# Pull the latest changes from the repo
git pull --rebase
# Run the web ui
python webui.py --precision full --no-half --opt-split-attention-v1 --use-cpu GFPGAN CodeFormer BSRGAN ESRGAN SCUNet
# Deactivate conda environment
conda deactivate
" > run_webui_mac.sh

# Give run permissions to the shell script
chmod +x run_webui_mac.sh

echo "============================================="
echo "============================================="
echo "==============MORE INFORMATION==============="
echo "============================================="
echo "============================================="
echo "If you want to run the web UI again, you can run the following command:"
echo "./stable-diffusion-webui/run_webui_mac.sh"
echo "or"
echo "cd stable-diffusion-webui && ./run_webui_mac.sh"
echo "============================================="
echo "============================================="
echo "============================================="
echo "============================================="


# Run the web UI
python webui.py --precision full --no-half --opt-split-attention-v1 --use-cpu GFPGAN CodeFormer BSRGAN ESRGAN SCUNet
