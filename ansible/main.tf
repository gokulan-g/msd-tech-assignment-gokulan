---
- name: Read Terraform statefile, create inventory file and setup webservers
  hosts: localhost
  gather_facts: false
  vars:
    tfstate_file: "terraform/terraform.tfstate"

  tasks:
    - name: Read terraform state
      set_fact:
        tf_instances: "{{ lookup('community.general.terraform_state', tfstate_file).resources }}"
    
    - name: Extract public IPs and hostnames from aws_instance resources
      set_fact:
        instances_info: >-
          {{
            tf_instances
            | selectattr('type', 'equalto', 'aws_instance')
            | selectattr('name', 'equalto', 'ubuntu_server')
            | map(attribute='instances')
            | sum(start=[])
            | map(attribute='attributes')
            | map('extract', ['public_ip', 'public_dns'])
            | list
          }}

    - name: Show extracted instance info
      debug:
        msg: "{{ instances_info }}"
    
    - name: Write inventories.ini file
      copy:
        dest: "ansible/inventories.ini"
        content: |
          [webservers]
          {% for ip, dns in instances_info %}
          {{ dns }} ansible_host={{ ip }}
          {% endfor %}
