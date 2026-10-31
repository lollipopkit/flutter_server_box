// Opens a monitor settings backup with filippo.io/age, the reference Go
// implementation, and nothing of ServerBox's: the key file with the
// passphrase (scrypt), then the backup with the key (X25519). Writes the
// backup's tar.gz.
//
//	SBM_BACKUP_PASSPHRASE=… go run . <key file> <backup> <out.tar.gz>
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"

	"filippo.io/age"
	"filippo.io/age/armor"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Fprintln(os.Stderr, "usage: agedecrypt <key file> <backup> <out.tar.gz>")
		os.Exit(2)
	}
	if err := run(os.Args[1], os.Args[2], os.Args[3]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(keyPath, backupPath, outPath string) error {
	scrypt, err := age.NewScryptIdentity(os.Getenv("SBM_BACKUP_PASSPHRASE"))
	if err != nil {
		return err
	}
	keyFile, err := os.Open(keyPath)
	if err != nil {
		return err
	}
	defer keyFile.Close()
	keyText, err := age.Decrypt(armor.NewReader(keyFile), scrypt)
	if err != nil {
		return fmt.Errorf("key file: %w", err)
	}
	var identity age.Identity
	scanner := bufio.NewScanner(keyText)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if strings.HasPrefix(line, "AGE-SECRET-KEY-") {
			if identity, err = age.ParseX25519Identity(line); err != nil {
				return err
			}
		}
	}
	if identity == nil {
		return fmt.Errorf("no key in the key file")
	}
	backup, err := os.Open(backupPath)
	if err != nil {
		return err
	}
	defer backup.Close()
	plain, err := age.Decrypt(backup, identity)
	if err != nil {
		return fmt.Errorf("backup: %w", err)
	}
	out, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, plain)
	return err
}
