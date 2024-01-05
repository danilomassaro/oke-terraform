#
# gru_localexec.tf
#

resource "null_resource" "gru_oke-kubectl-cmds" { 

    provisioner "local-exec" {
        command = "./oke-init.sh"
        working_dir = "./scripts"
        on_failure = fail
    }     

    depends_on = [       
        oci_containerengine_node_pool.gru_oke_motando_np-1
    ]  
}

/*
resource "null_resource" "gru_oke-k10" { 

    provisioner "local-exec" {
        command = "./oke-k10.sh"
        working_dir = "./scripts"
        on_failure = fail
    }     

    depends_on = [       
        oci_containerengine_cluster.gru_oke_motando
    ]  
}
*/