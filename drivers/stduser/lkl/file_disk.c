#include <linux/kernel.h>
#include <linux/genhd.h>
#include <linux/blkdev.h>
#include <linux/buffer_head.h>	/* invalidate_bdev */
#include <linux/bio.h>

#include "file_disk.h"

/*
 * The internal representation of our device.
 */
struct file_disk_dev {
	void *f;
        spinlock_t lock;                /* For mutual exclusion */
        struct request_queue *queue;    /* The device request queue */
        struct gendisk *gd;             /* The gendisk structure */
};


static void file_disk_request(request_queue_t *q)
{
	struct request *req;

	while ((req = elv_next_request(q)) != NULL) {
		struct file_disk_dev *dev = req->rq_disk->private_data;
		if (! blk_fs_request(req)) {
			printk (KERN_NOTICE "Skip non-fs request\n");
			end_request(req, 0);
			continue;
		}
		_file_rw(dev->f, req->sector, req->current_nr_sectors,
				req->buffer, rq_data_dir(req));
		end_request(req, 1);
	}
}


static int file_disk_open(struct inode *inode, struct file *filp)
{
	struct file_disk_dev *dev = inode->i_bdev->bd_disk->private_data;

	filp->private_data = dev;
	return 0;
}

/*
 * The device operations structure.
 */
static struct block_device_operations file_disk_ops = {
	.owner           = THIS_MODULE,
	.open 	         = file_disk_open,
};

static int major;

/*
 * Set up our internal device.
 */
int file_disk_add_disk(const char *filename, int which, dev_t *devno)
{
	struct file_disk_dev *dev=kmalloc(sizeof(*dev), GFP_KERNEL);

	BUG_ON(dev == NULL);

	memset (dev, 0, sizeof (struct file_disk_dev));

        dev->f=_file_open();
	BUG_ON(dev->f == NULL);

	spin_lock_init(&dev->lock);
	
        dev->queue = blk_init_queue(file_disk_request, &dev->lock);
	BUG_ON(dev->queue == NULL);

	blk_queue_hardsect_size(dev->queue, 512);
	dev->queue->queuedata = dev;

	dev->gd = alloc_disk(1);
	BUG_ON(dev->gd == NULL);

	dev->gd->major = major;
	dev->gd->first_minor = which;
	dev->gd->fops = &file_disk_ops;
	dev->gd->queue = dev->queue;
	dev->gd->private_data = dev;
	snprintf (dev->gd->disk_name, 32, "fd:%s", filename);
	set_capacity(dev->gd, _file_sectors());

	add_disk(dev->gd);

	printk("fd: initialized %s with dev=%d:%d\n", dev->gd->disk_name, dev->gd->major, dev->gd->first_minor);
	*devno=new_encode_dev(MKDEV(dev->gd->major, dev->gd->first_minor));

	return 0;
}

static int __init file_disk_init(void)
{
	major = register_blkdev(0, "fd");
	if (major < 0) {
		printk(KERN_ERR "fd: unable to register_blkdev: %d\n", major);
		return -EBUSY;
	}

	return 0;
}

late_initcall(file_disk_init);
