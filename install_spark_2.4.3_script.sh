#!/bin/bash
##################
# Author: Jordan Simbananiye
# Date: 26-07-19
#
# Bash script to install spark onto ubuntu 18.04 machine
###################

##
## Perhaps do clean up in one function at the end
##

set -e
# set -x # for debugging

printf "Beginning spark install... \n"
CURRENT_DIRECTORY=$(dirname $0)
SPARK_DOWNLOAD_URL=$1
SPARK_HOME=$2
SPARK_VERSION=$3 # In format spark-2.x.x... Make this known in help command.

## Validate install i.e. check download contains spark version
## Perhaps this can be hard coded, since we will not be using that as a variable

## Check if spark home alread exists
printf -- "\n"
printf "Checking existing directories... \n"
if [ -d "$SPARK_HOME" ]; then
    printf "$SPARK_HOME already exists on this machine \n"
    printf "Deleting $SPARK_HOME for fresh install... \n"

    if [ -L $SPARK_HOME ]; then
        # directory is a symlink
        rm $SPARK_HOME
    else
        rm -rf $SPARK_HOME
    fi

fi

## Create SPARK_HOME directory
printf -- "\n"
printf "creating directory $SPARK_HOME ... \n"
mkdir $SPARK_HOME

printf -- "\n"
printf "Setting SPARK_HOME env var to: $2\n" 
printf "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin \n"
# Pipe command above into profile or bashrc or bash_profile on target

## Download spark tarball from url provided
printf -- "\n"
printf "Downloading spark from $1 \n"
curl -OL $1
BIN_DOWNLOAD_SUCCESS=$? #$? contains output exit code of most recently ran command
SPARK_TAR=''
if [ $BIN_DOWNLOAD_SUCCESS -eq 0 ]; then
    # This is happy path
    SPARK_TAR=$(ls *$SPARK_VERSION*.tgz) # Get file name of most recent file added to pwd
    printf "Successfully downloaded spark tar: $SPARK_TAR \n" 
else
    printf "failed to download from: $SPARK_DOWNLOAD_URL \n"
    exit 2
fi

##Verify the download -- Add flag for this part to be active
printf -- '\n'; 
printf "Verifying download of $SPARK_DOWNLOAD_URL \n"

GPG_COMMAND_LOC=$(command -v gpg)
if ! [ GPG_COMMAND_LOC ]; then
    # exit script
    printf "GPG is not installed on this system to verify the download, please install it. \n"
    exit 3 # Cannot verify download
else
    printf "calculating hash of downloaded file"
    TEMP_HASH_FILE="temp_hash_file"
    touch $TEMP_HASH_FILE
    gpg --print-md SHA512 $SPARK_TAR > $TEMP_HASH_FILE 2>/dev/null # Silence warning when running as root with sudo 
    CALCULATED_HASH=$(cat $TEMP_HASH_FILE)
    printf "... Done \n"
    printf "Calculated SHA512 hash: $CALCULATED_HASH \n"
    rm $TEMP_HASH_FILE # Clean up pwd

    printf "Retreiving SHA512 hash from source to verify against... \n"
    HASH_SOURCE="https://apache.org/dist/spark/$SPARK_VERSION/$SPARK_TAR.sha512"
    curl -O $HASH_SOURCE # Consider silencing curl output
    APACHE_HASH_FILE="$SPARK_TAR.sha512"
    HASH_DOWNLOAD_SUCCESS=$?
    if [ $HASH_DOWNLOAD_SUCCESS -eq 0 ]; then
        printf "Done \n"
        RETREIVED_HASH=$(cat $APACHE_HASH_FILE)
        printf "Retreived hash: $RETREIVED_HASH \n"
        printf "from $HASH_SOURCE \n"

    else
        printf -- "\n"
        printf "There has been an error retrieving the hash $HASH_SOURCE \n"
        printf "Please invesitage or run without verification enabled \n" # This is linked to the idea of a flag to run with verification or not
    fi
fi

if ! [ "$CALCULATED_HASH" == "$RETREIVED_HASH" ]; then
    printf "The download did not pass verification, please check your download source is trustworthy! \n"
else
    rm $APACHE_HASH_FILE # Clean up downloaded hash file from Apache.
    printf "Download is verified! \n"
fi

## Extract Spark tar and move contents to SPARK_HOME
printf -- "\n"
printf "Extracting Spark zip file... "
tar -xf $SPARK_TAR
UNZIP_SUCCESS=$?
if [ $UNZIP_SUCCESS -eq 0 ]; then
    printf "Done \n"
    SPARK_TAR_EXTRACT=${SPARK_TAR%.*} # Regex to remove any extension of the zip SPARK file
    [ -e $SPARK_TAR_EXTRACT ] && printf "Spark binaries in $SPARK_TAR_EXTRACT \n"
    printf "Moving extracted files to $SPARK_HOME... "
    mv "${SPARK_TAR_EXTRACT}/"* "${SPARK_HOME}/" # Trailing slash to copy only contents to SPARK_HOME, wild card outside due to expansions
    printf "Done \n"
    # Clean up of current working directory
    if [ -z "$(ls -A $SPARK_TAR_EXTRACT)" ]; then # Test if spark extracted dir is now empty
        rmdir $SPARK_TAR_EXTRACT
    else 
        printf "Unable to delete $SPARK_TAR_EXTRACT"
        printf "Check if all content has been moved out of $SPARK_TAR_EXTRACT \n"
    fi
else
    printf "There has been error unzipping $SPARK_TAR"
fi


## Update profile / .bashrc
echo "
export SPARK_HOME=$SPARK_HOME
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin

" >> ~/.bashrc

source ~/.bashrc
printf -- "\n"