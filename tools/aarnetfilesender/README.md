Filesendercli wrapper
======================

Galaxy wrapper of the AARNET
`filesender <https://support.aarnet.edu.au/hc/en-us/articles/230067927-Send-files-with-FileSender>`__.

Setting up credentials on Galaxy
--------------------------------

The admin can enable users to set their own credentials
for this tool. To enable it, make sure the file
``config/user_preferences_extra_conf.yml`` has the following section:

.. code-block:: yaml

    aarnet_filesender_account:
        description: AARNet FileSender Account Info
        inputs:
            - name: username
              label: AARNet FileSender Username
              type: text
              required: False
            - name: apikey
              label: AARNet FileSender API Key
              type: password
              required: False
