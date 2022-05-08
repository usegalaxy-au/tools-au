EXPECTED_ENV=`echo $CONDA_PREFIX | sed 's/@0//'`
if [ ! -d $EXPECTED_ENV ]; then
  ln -s $CONDA_PREFIX $EXPECTED_ENV
fi
